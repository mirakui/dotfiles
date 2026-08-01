#!/usr/bin/env bash
#
# assess-command.sh - Claude Code PreToolUse hook that evaluates the safety
# of Bash commands not covered by allow/ask/deny in settings.json.
#
# Output (stderr): safety 1-5, summary, side effects, risks.
# Always exits 0 so the normal permission flow is never blocked.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="${ASSESS_SETTINGS_FILE:-${SCRIPT_DIR}/../settings.json}"
CACHE_DIR="${ASSESS_CACHE_DIR:-${HOME}/.claude/cache/assess-command}"
CACHE_TTL_DAYS="${ASSESS_CACHE_TTL_DAYS:-30}"
MODEL="${ASSESS_MODEL:-claude-haiku-4-5}"
LOG_FILE="${ASSESS_LOG_FILE:-${HOME}/.claude/logs/assess-command.jsonl}"

input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty')
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
permission_mode=$(printf '%s' "$input" | jq -r '.permission_mode // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

if [[ "$tool_name" != "Bash" || -z "$command" ]]; then
  exit 0
fi

# Bypass when a sentinel file exists under the session cwd
if [[ -n "$cwd" && -f "${cwd}/.cctmp/BYPASS_CHECK_HOOKS" ]]; then
  bypass_msg="[assess-command] .cctmp/BYPASS_CHECK_HOOKS によりスキップ"
  jq -cn --arg msg "$bypass_msg" '{
    systemMessage: $msg,
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: $msg
    }
  }'
  exit 0
fi

if [[ ! -f "$SETTINGS_FILE" ]]; then
  exit 0
fi

extract_patterns() {
  local key="$1"
  jq -r --arg key "$key" '
    .permissions[$key] // []
    | .[]
    | select(startswith("Bash("))
    | gsub("^Bash\\("; "")
    | gsub("\\)$"; "")
    | gsub(":"; " ")
  ' "$SETTINGS_FILE" 2>/dev/null || true
}

allow_patterns=$(extract_patterns allow)
ask_patterns=$(extract_patterns ask)
deny_patterns=$(extract_patterns deny)
known_patterns=$(printf '%s\n%s\n%s\n' "$allow_patterns" "$ask_patterns" "$deny_patterns")

segment_is_known() {
  local seg="$1"
  seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -z "$seg" ]] && return 0

  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    local base="${pattern% \*}"
    # shellcheck disable=SC2053
    if [[ "$seg" == $base ]] || [[ "$seg" == $base" "* ]]; then
      return 0
    fi
  done <<< "$known_patterns"
  return 1
}

all_segments_known() {
  local full="$1"
  local segments
  segments=$(printf '%s' "$full" | sed 's/[;]/\n/g; s/&&/\n/g; s/||/\n/g')
  while IFS= read -r seg; do
    [[ -z "$(printf '%s' "$seg" | tr -d '[:space:]')" ]] && continue
    if ! segment_is_known "$seg"; then
      return 1
    fi
  done <<< "$segments"
  return 0
}

if all_segments_known "$command"; then
  exit 0
fi

hash_command() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  else
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  fi
}

cache_is_fresh() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local now mtime age_days
  now=$(date +%s)
  if stat -f %m "$file" >/dev/null 2>&1; then
    mtime=$(stat -f %m "$file")
  else
    mtime=$(stat -c %Y "$file")
  fi
  age_days=$(( (now - mtime) / 86400 ))
  (( age_days < CACHE_TTL_DAYS ))
}

mkdir -p "$CACHE_DIR"
cache_key=$(hash_command "$command")
cache_file="${CACHE_DIR}/${cache_key}.json"

SYSTEM_PROMPT=$'You evaluate the safety of a Bash command that a developer is about to run on a macOS/Linux workstation.\n\
Rules:\n\
- Output MUST be valid JSON matching the provided schema.\n\
- safety: 1 (destructive, irreversible, or high blast radius) .. 5 (read-only, no external effects).\n\
- Routine local version-control bookkeeping is safe: treat `git add` and `git commit` as safety 4 regardless of flags, multi-line commit messages, or shell metacharacters (&& || ;) inside the commit message.\n\
- A non-force `git push` (without --force / -f / --force-with-lease) is safety 3. A force push, or history-rewriting / destructive git commands (reset --hard, rebase, checkout, clean, filter-branch), is NOT covered by these overrides and should be rated by its actual blast radius (typically 1-2).\n\
- summary: one sentence in Japanese describing what the command does.\n\
- sideEffects: one sentence in Japanese listing filesystem/network/process changes. Write "\xe3\x81\xaa\xe3\x81\x97" (none) if read-only.\n\
- risks: one sentence in Japanese describing what could go wrong (data loss, exfiltration, resource exhaustion, etc.). Write "\xe3\x81\xaa\xe3\x81\x97" if essentially safe.\n\
- Keep each string under 120 characters. Be concrete about paths and actions.\n'

JSON_SCHEMA='{"type":"object","properties":{"safety":{"type":"integer","minimum":1,"maximum":5},"summary":{"type":"string"},"sideEffects":{"type":"string"},"risks":{"type":"string"}},"required":["safety","summary","sideEffects","risks"]}'

evaluate_via_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    return 127
  fi
  claude -p \
    --output-format json \
    --system-prompt "$SYSTEM_PROMPT" \
    --model "$MODEL" \
    --json-schema "$JSON_SCHEMA" \
    "Command: ${command}" 2>/dev/null
}

emit_system_message() {
  local msg="$1"
  local decision="${2:-ask}"
  jq -cn --arg msg "$msg" --arg decision "$decision" '{
    systemMessage: $msg,
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: $decision,
      permissionDecisionReason: $msg
    }
  }'
}

assessment=""
cache_hit=false
if cache_is_fresh "$cache_file"; then
  assessment=$(cat "$cache_file")
  cache_hit=true
else
  raw_response=""
  rc=0
  raw_response=$(evaluate_via_claude) || rc=$?
  if (( rc != 0 )); then
    if (( rc == 127 )); then
      emit_system_message "[assess-command] 安全性評価をスキップしました (claude CLI が見つかりません)"
    else
      emit_system_message "[assess-command] 安全性評価をスキップしました (claude CLI 実行失敗: exit ${rc})"
    fi
    exit 0
  fi
  if [[ -z "$raw_response" ]]; then
    emit_system_message "[assess-command] 安全性評価をスキップしました (claude CLI 応答なし)"
    exit 0
  fi
  is_error=$(printf '%s' "$raw_response" | jq -r '.is_error // false' 2>/dev/null)
  if [[ "$is_error" == "true" ]]; then
    api_status=$(printf '%s' "$raw_response" | jq -r '.api_error_status // empty' 2>/dev/null)
    err_result=$(printf '%s' "$raw_response" | jq -r '.result // empty' 2>/dev/null)
    detail="HTTP ${api_status:-?}: ${err_result:-不明なエラー}"
    emit_system_message "[assess-command] 安全性評価をスキップしました (${detail})"
    exit 0
  fi
  assessment=$(printf '%s' "$raw_response" | jq -c '.structured_output // empty' 2>/dev/null)
  if [[ -z "$assessment" ]]; then
    emit_system_message "[assess-command] 安全性評価をスキップしました (構造化出力なし)"
    exit 0
  fi
  printf '%s' "$assessment" > "$cache_file"
fi

if [[ -z "$assessment" ]]; then
  exit 0
fi

safety=$(printf '%s' "$assessment" | jq -r '.safety // empty')
summary=$(printf '%s' "$assessment" | jq -r '.summary // empty')
side_effects=$(printf '%s' "$assessment" | jq -r '.sideEffects // empty')
risks=$(printf '%s' "$assessment" | jq -r '.risks // empty')

if [[ -z "$safety" ]]; then
  exit 0
fi

mkdir -p "$(dirname "$LOG_FILE")"
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
jq -cn \
  --arg ts "$timestamp" \
  --arg cmd "$command" \
  --argjson safety "$safety" \
  --arg summary "$summary" \
  --arg side_effects "$side_effects" \
  --arg risks "$risks" \
  --argjson cache_hit "$cache_hit" \
  --arg permission_mode "$permission_mode" \
  '{timestamp: $ts, command: $cmd, safety: $safety, summary: $summary, sideEffects: $side_effects, risks: $risks, cache_hit: $cache_hit, permissionMode: $permission_mode}' \
  >> "$LOG_FILE" 2>/dev/null || true

case "$safety" in
  1) icon="🔴"; label="非常に危険" ;;
  2) icon="🟠"; label="危険" ;;
  3) icon="🟡"; label="注意" ;;
  4) icon="🟢"; label="比較的安全" ;;
  5) icon="✅"; label="安全" ;;
  *) icon="❔"; label="評価不能" ;;
esac

message=$(printf '🛡️Bash 安全性評価\n  安全度: %s %s/5 (%s)\n  概要:   %s\n  副作用: %s\n  リスク: %s' \
  "$icon" "$safety" "$label" "$summary" "$side_effects" "$risks")

if [[ "$permission_mode" == "auto" ]]; then
  threshold=3
else
  threshold=5
fi

if (( safety >= threshold )); then
  emit_system_message "$message" "allow"
else
  emit_system_message "$message"
fi

exit 0
