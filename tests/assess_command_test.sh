#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/claude/scripts/assess-command.sh"

mkdir -p "${ROOT_DIR}/.cctmp/scratch"
tmp="$(mktemp -d "${ROOT_DIR}/.cctmp/scratch/assess-command-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Minimal settings.json fixture
cat > "${tmp}/settings.json" <<'JSON'
{
  "permissions": {
    "allow": [
      "Bash(ls:*)",
      "Bash(git status:*)"
    ],
    "ask": [
      "Bash(git push:*)"
    ],
    "deny": [
      "Bash(rm:*)"
    ]
  }
}
JSON

export ASSESS_SETTINGS_FILE="${tmp}/settings.json"
export ASSESS_CACHE_DIR="${tmp}/cache"
export ASSESS_CACHE_TTL_DAYS=30
export ASSESS_LOG_FILE="${tmp}/assess-command.jsonl"

# Counter-tracking claude stub: records each invocation
stub_bin="${tmp}/stub-bin"
mkdir -p "$stub_bin"
call_log="${tmp}/claude-calls.log"
touch "$call_log"

cat > "${stub_bin}/claude" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "called" >> "${call_log}"
cat <<'JSON'
{"structured_output":{"safety":2,"summary":"\u672a\u77e5\u30b3\u30de\u30f3\u30c9\u306e\u30c6\u30b9\u30c8","sideEffects":"\u306a\u3057","risks":"\u30c6\u30b9\u30c8\u7528\u30c0\u30df\u30fc"}}
JSON
EOF
chmod +x "${stub_bin}/claude"

# Variant stub returning safety:3 for threshold tests
stub_bin_safety3="${tmp}/stub-bin-safety3"
mkdir -p "$stub_bin_safety3"
cat > "${stub_bin_safety3}/claude" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "called" >> "${call_log}"
cat <<'JSON'
{"structured_output":{"safety":3,"summary":"\u672a\u77e5\u30b3\u30de\u30f3\u30c9","sideEffects":"\u306a\u3057","risks":"\u306a\u3057"}}
JSON
EOF
chmod +x "${stub_bin_safety3}/claude"

# Variant stub simulating Anthropic API 401 (expired OAuth token)
stub_bin_401="${tmp}/stub-bin-401"
mkdir -p "$stub_bin_401"
cat > "${stub_bin_401}/claude" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "called" >> "${call_log}"
cat <<'JSON'
{"type":"result","subtype":"success","is_error":true,"api_error_status":401,"result":"Failed to authenticate. API Error: 401 Invalid authentication credentials"}
JSON
EOF
chmod +x "${stub_bin_401}/claude"

run_hook() {
  local cmd="$1"
  local mode="${2:-}"
  local input
  if [[ -n "$mode" ]]; then
    input=$(jq -cn --arg c "$cmd" --arg m "$mode" \
      '{tool_name:"Bash", tool_input:{command:$c}, permission_mode:$m}')
  else
    input=$(jq -cn --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  fi
  PATH="${stub_bin}:$PATH" bash "$SCRIPT" <<< "$input"
}

run_hook_with_stub() {
  local stub="$1"
  local cmd="$2"
  local mode="${3:-}"
  local input
  if [[ -n "$mode" ]]; then
    input=$(jq -cn --arg c "$cmd" --arg m "$mode" \
      '{tool_name:"Bash", tool_input:{command:$c}, permission_mode:$m}')
  else
    input=$(jq -cn --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  fi
  PATH="${stub}:$PATH" bash "$SCRIPT" <<< "$input"
}

extract_message() {
  jq -r '.systemMessage // empty' 2>/dev/null
}

assert_no_claude_call() {
  local label="$1"
  if [[ -s "$call_log" ]]; then
    echo "FAIL [${label}]: claude was called unexpectedly" >&2
    cat "$call_log" >&2
    exit 1
  fi
}

assert_claude_called() {
  local label="$1"
  if [[ ! -s "$call_log" ]]; then
    echo "FAIL [${label}]: claude should have been called but was not" >&2
    exit 1
  fi
}

reset_calls() {
  : > "$call_log"
  rm -rf "${tmp}/cache"
  rm -f "$ASSESS_LOG_FILE"
}

# 1. Non-Bash tool -> skip silently
reset_calls
out=$(echo '{"tool_name":"Read","tool_input":{"command":"ignored"}}' | PATH="${stub_bin}:$PATH" bash "$SCRIPT")
if [[ -n "$out" ]]; then
  echo "FAIL [non-bash]: expected no output, got: $out" >&2
  exit 1
fi
assert_no_claude_call "non-bash"

# 2. allow-matched single command -> skip
reset_calls
out=$(run_hook "ls -la")
if [[ -n "$out" ]]; then
  echo "FAIL [allow]: expected silent skip, got: $out" >&2
  exit 1
fi
assert_no_claude_call "allow"

# 3. deny-matched command -> skip (deny-check.sh handles it separately)
reset_calls
out=$(run_hook "rm -rf /tmp/foo")
if [[ -n "$out" ]]; then
  echo "FAIL [deny]: expected silent skip, got: $out" >&2
  exit 1
fi
assert_no_claude_call "deny"

# 4. ask-matched command -> skip
reset_calls
out=$(run_hook "git push origin main")
if [[ -n "$out" ]]; then
  echo "FAIL [ask]: expected silent skip, got: $out" >&2
  exit 1
fi
assert_no_claude_call "ask"

# 5. Unknown command -> evaluate, emit systemMessage JSON on stdout, log to file
reset_calls
msg=$(run_hook "ncdu /" | extract_message)
if ! grep -q "Bash 安全性評価" <<< "$msg"; then
  echo "FAIL [unknown]: expected assessment header, got: $msg" >&2
  exit 1
fi
if ! grep -q "2/5" <<< "$msg"; then
  echo "FAIL [unknown]: expected safety 2/5, got: $msg" >&2
  exit 1
fi
assert_claude_called "unknown"
# Verify log entry
if [[ ! -s "$ASSESS_LOG_FILE" ]]; then
  echo "FAIL [unknown/log]: expected log file to exist with content" >&2
  exit 1
fi
entry=$(tail -n 1 "$ASSESS_LOG_FILE")
for field in command safety summary sideEffects risks timestamp cache_hit; do
  if ! jq -e "has(\"${field}\")" <<< "$entry" >/dev/null; then
    echo "FAIL [unknown/log]: missing field ${field} in log entry: $entry" >&2
    exit 1
  fi
done
logged_cmd=$(jq -r '.command' <<< "$entry")
logged_safety=$(jq -r '.safety' <<< "$entry")
logged_cache=$(jq -r '.cache_hit' <<< "$entry")
if [[ "$logged_cmd" != "ncdu /" ]] || [[ "$logged_safety" != "2" ]] || [[ "$logged_cache" != "false" ]]; then
  echo "FAIL [unknown/log]: unexpected log entry values: $entry" >&2
  exit 1
fi

# 6. Cache hit on second run with same command -> no claude call, log cache_hit=true
reset_calls
run_hook "foobar --baz" >/dev/null 2>&1
assert_claude_called "cache-prime"
: > "$call_log"
: > "$ASSESS_LOG_FILE"
msg=$(run_hook "foobar --baz" | extract_message)
if ! grep -q "2/5" <<< "$msg"; then
  echo "FAIL [cache]: expected cached assessment, got: $msg" >&2
  exit 1
fi
assert_no_claude_call "cache"
logged_cache=$(jq -r '.cache_hit' < "$ASSESS_LOG_FILE")
if [[ "$logged_cache" != "true" ]]; then
  echo "FAIL [cache/log]: expected cache_hit=true, got: $(cat "$ASSESS_LOG_FILE")" >&2
  exit 1
fi

# 7. Compound command where every segment is known -> skip
reset_calls
out=$(run_hook "ls && git status")
if [[ -n "$out" ]]; then
  echo "FAIL [compound-known]: expected silent skip, got: $out" >&2
  exit 1
fi
assert_no_claude_call "compound-known"

# 8. Compound command with one unknown segment -> evaluate
reset_calls
msg=$(run_hook "ls && foo_unknown_xyz" | extract_message)
if ! grep -q "Bash 安全性評価" <<< "$msg"; then
  echo "FAIL [compound-unknown]: expected assessment, got: $msg" >&2
  exit 1
fi
assert_claude_called "compound-unknown"

# 9. claude CLI missing -> must still exit 0 without disrupting flow
reset_calls
empty_bin="${tmp}/empty-bin"
mkdir -p "$empty_bin"
out=$(echo '{"tool_name":"Bash","tool_input":{"command":"novel_cmd_no_cache"}}' \
  | PATH="${empty_bin}:/usr/bin:/bin" bash "$SCRIPT") || {
  echo "FAIL [no-claude]: hook exited non-zero when claude missing" >&2
  exit 1
}
msg=$(extract_message <<< "$out")
if ! grep -q "スキップ" <<< "$msg"; then
  echo "FAIL [no-claude]: expected skip systemMessage, got: $out" >&2
  exit 1
fi

# 10. permission_mode=auto + safety=3 -> allow (lowered threshold)
reset_calls
out=$(run_hook_with_stub "$stub_bin_safety3" "novel_auto_threshold_3" "auto")
decision=$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$out")
if [[ "$decision" != "allow" ]]; then
  echo "FAIL [auto-3]: expected allow, got: $decision (full output: $out)" >&2
  exit 1
fi
# Log should record permissionMode=auto
logged_mode=$(jq -r '.permissionMode' < "$ASSESS_LOG_FILE")
if [[ "$logged_mode" != "auto" ]]; then
  echo "FAIL [auto-3/log]: expected permissionMode=auto, got: $logged_mode" >&2
  exit 1
fi

# 11. permission_mode=default + safety=3 -> ask (default threshold stays at 5)
reset_calls
out=$(run_hook_with_stub "$stub_bin_safety3" "novel_default_threshold_3" "default")
decision=$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$out")
if [[ "$decision" != "ask" ]]; then
  echo "FAIL [default-3]: expected ask, got: $decision (full output: $out)" >&2
  exit 1
fi

# 12. permission_mode=auto + safety=2 -> ask (still below auto threshold of 3)
reset_calls
out=$(run_hook "novel_auto_threshold_2" "auto")
decision=$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$out")
if [[ "$decision" != "ask" ]]; then
  echo "FAIL [auto-2]: expected ask, got: $decision (full output: $out)" >&2
  exit 1
fi

# 13. BYPASS file present at cwd/.cctmp/BYPASS_CHECK_HOOKS -> skip claude, emit allow with BYPASS marker
reset_calls
bypass_cwd="${tmp}/proj-with-bypass"
mkdir -p "${bypass_cwd}/.cctmp"
touch "${bypass_cwd}/.cctmp/BYPASS_CHECK_HOOKS"
input=$(jq -cn --arg c "novel_bypassed_cmd_xyz" --arg w "$bypass_cwd" \
  '{tool_name:"Bash", tool_input:{command:$c}, cwd:$w}')
out=$(PATH="${stub_bin}:$PATH" bash "$SCRIPT" <<< "$input")
decision=$(jq -r '.hookSpecificOutput.permissionDecision' <<< "$out")
msg=$(extract_message <<< "$out")
if [[ "$decision" != "allow" ]]; then
  echo "FAIL [bypass]: expected allow, got: $decision (full: $out)" >&2
  exit 1
fi
if ! grep -q "BYPASS_CHECK_HOOKS" <<< "$msg"; then
  echo "FAIL [bypass]: expected BYPASS_CHECK_HOOKS marker, got: $msg" >&2
  exit 1
fi
assert_no_claude_call "bypass"

# 13b. claude returns is_error:true with api_error_status -> emit detailed skip message
reset_calls
out=$(run_hook_with_stub "$stub_bin_401" "novel_401_test_cmd")
msg=$(extract_message <<< "$out")
if ! grep -q "401" <<< "$msg"; then
  echo "FAIL [api-error]: expected 401 in systemMessage, got: $msg" >&2
  exit 1
fi
if ! grep -q "Failed to authenticate" <<< "$msg"; then
  echo "FAIL [api-error]: expected upstream error text in msg, got: $msg" >&2
  exit 1
fi
# Error response must NOT be cached
err_cache_key=$(printf '%s' "novel_401_test_cmd" | shasum -a 256 | awk '{print $1}')
if [[ -f "${tmp}/cache/${err_cache_key}.json" ]]; then
  echo "FAIL [api-error/cache]: error response should not be cached" >&2
  exit 1
fi

# 14. cwd given but BYPASS file absent -> normal evaluation path runs
reset_calls
nobypass_cwd="${tmp}/proj-without-bypass"
mkdir -p "$nobypass_cwd"
input=$(jq -cn --arg c "novel_normal_path_cmd" --arg w "$nobypass_cwd" \
  '{tool_name:"Bash", tool_input:{command:$c}, cwd:$w}')
out=$(PATH="${stub_bin}:$PATH" bash "$SCRIPT" <<< "$input")
msg=$(extract_message <<< "$out")
if ! grep -q "Bash 安全性評価" <<< "$msg"; then
  echo "FAIL [no-bypass-file]: expected normal assessment, got: $msg" >&2
  exit 1
fi
assert_claude_called "no-bypass-file"

echo "assess-command: all assertions passed"
