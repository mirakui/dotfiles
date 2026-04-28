#!/bin/bash
#
# session-title-prefix.sh - Claude Code UserPromptSubmit hook that prefixes
# the auto-generated session title with the current git repository name.
#
# Reads the current `summary` from sessions-index.json and emits
# hookSpecificOutput.sessionTitle = "[<repo>] <summary>" when not yet prefixed.
# Does nothing (exit 0 with empty stdout) on any error path so the session
# is never blocked.

set -uo pipefail

input=$(cat)

session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)

if [[ -z "$session_id" || -z "$cwd" ]]; then
  exit 0
fi

repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
if [[ -n "$repo_root" ]]; then
  repo_name=$(basename "$repo_root")
else
  repo_name=$(basename "$cwd")
fi

if [[ -z "$repo_name" ]]; then
  exit 0
fi

prefix="[${repo_name}] "

project_id=$(printf '%s' "$cwd" | sed 's|/|-|g')
index_file="$HOME/.claude/projects/${project_id}/sessions-index.json"

if [[ ! -f "$index_file" ]]; then
  exit 0
fi

summary=$(jq -r --arg sid "$session_id" '
  .entries // []
  | .[]
  | select(.sessionId == $sid)
  | .summary // empty
' "$index_file" 2>/dev/null || true)

if [[ -z "$summary" ]]; then
  exit 0
fi

if [[ "$summary" == "$prefix"* ]]; then
  exit 0
fi

new_title="${prefix}${summary}"

jq -cn --arg title "$new_title" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    sessionTitle: $title
  }
}'

exit 0
