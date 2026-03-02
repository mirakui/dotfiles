#!/bin/bash
#
# hook-logger.sh - Claude Code hook for logging tool usage and permission requests
#
# Logs PreToolUse and PermissionRequest events to monthly JSONL files.
# Target: Bash, WebSearch, WebFetch, MCP tools (configured via matcher in settings.json)
#
# Exit codes:
#   0 - Always succeeds (logging failure must not block tool execution)

set -uo pipefail

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

MONTH=$(date +"%Y%m")
LOG_FILE="$LOG_DIR/tool-use-${MONTH}.jsonl"

input=$(cat)

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "$input" | jq -c \
  --arg ts "$timestamp" \
  '{timestamp: $ts, session_id: .session_id, event: .hook_event_name, tool_name: .tool_name, tool_input: .tool_input}' \
  >> "$LOG_FILE"

exit 0
