#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/claude/scripts/deny-check.sh"

mkdir -p "${ROOT_DIR}/.cctmp/scratch"
tmp="$(mktemp -d "${ROOT_DIR}/.cctmp/scratch/deny-check-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

run_hook() {
  local cmd="$1"
  local cwd="${2:-}"
  local input
  if [[ -n "$cwd" ]]; then
    input=$(jq -cn --arg c "$cmd" --arg w "$cwd" \
      '{tool_name:"Bash", tool_input:{command:$c}, cwd:$w}')
  else
    input=$(jq -cn --arg c "$cmd" \
      '{tool_name:"Bash", tool_input:{command:$c}}')
  fi
  bash "$SCRIPT" <<< "$input"
}

# 1. Non-Bash tool -> exit 0 silently
out=$(echo '{"tool_name":"Read","tool_input":{"command":"rm -rf /"}}' | bash "$SCRIPT")
if [[ -n "$out" ]]; then
  echo "FAIL [non-bash]: expected no output, got: $out" >&2
  exit 1
fi

# 2. Allowed command (not in deny list) -> exit 0, no stdout
out=$(run_hook "ls -la")
if [[ -n "$out" ]]; then
  echo "FAIL [allow]: expected no output, got: $out" >&2
  exit 1
fi

# 3. Denied command -> exit 2 with DENIED in stderr
set +e
err=$(run_hook "rm -rf /tmp/foo" 2>&1 >/dev/null)
rc=$?
set -e
if [[ $rc -ne 2 ]]; then
  echo "FAIL [deny]: expected exit 2, got $rc (stderr: $err)" >&2
  exit 1
fi
if ! grep -q "DENIED" <<< "$err"; then
  echo "FAIL [deny]: expected DENIED in stderr, got: $err" >&2
  exit 1
fi

# 4. BYPASS file present at cwd/.cctmp/BYPASS_CHECK_HOOKS -> skip deny, exit 0, emit systemMessage
bypass_cwd="${tmp}/proj-with-bypass"
mkdir -p "${bypass_cwd}/.cctmp"
touch "${bypass_cwd}/.cctmp/BYPASS_CHECK_HOOKS"
set +e
out=$(run_hook "rm -rf /tmp/foo" "$bypass_cwd" 2>/dev/null)
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo "FAIL [bypass]: expected exit 0 when bypass file exists, got $rc" >&2
  exit 1
fi
msg=$(jq -r '.systemMessage // empty' <<< "$out" 2>/dev/null || echo "")
if [[ -z "$msg" ]]; then
  echo "FAIL [bypass]: expected systemMessage in stdout, got: $out" >&2
  exit 1
fi
if ! grep -q "BYPASS_CHECK_HOOKS" <<< "$msg"; then
  echo "FAIL [bypass]: expected BYPASS_CHECK_HOOKS marker in msg, got: $msg" >&2
  exit 1
fi

# 5. cwd given but BYPASS file absent -> normal deny behavior preserved
nobypass_cwd="${tmp}/proj-without-bypass"
mkdir -p "$nobypass_cwd"
set +e
err=$(run_hook "rm -rf /tmp/foo" "$nobypass_cwd" 2>&1 >/dev/null)
rc=$?
set -e
if [[ $rc -ne 2 ]]; then
  echo "FAIL [no-bypass-file]: expected exit 2 with no bypass file, got $rc" >&2
  exit 1
fi

# 6. BYPASS file present but command would normally be allowed -> still exit 0 (bypass is permissive, not corrective)
set +e
out=$(run_hook "ls -la" "$bypass_cwd" 2>/dev/null)
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo "FAIL [bypass-allowed]: expected exit 0 for normally-allowed command, got $rc" >&2
  exit 1
fi

echo "deny-check: all assertions passed"
