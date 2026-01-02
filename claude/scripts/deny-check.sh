#!/bin/bash
#
# deny-check.sh - Claude Code PreToolUse hook for blocking dangerous Bash commands
#
# This script intercepts Bash commands and blocks those matching denial patterns
# defined in settings.json. It handles compound commands separated by ;, &&, ||
#
# Exit codes:
#   0 - Command permitted
#   2 - Command denied (dangerous operation blocked)

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="${SCRIPT_DIR}/../settings.json"

# Read JSON input from stdin
input=$(cat)

# Extract tool name and command from input
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only process Bash tool calls
if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

# If no command, allow
if [[ -z "$command" ]]; then
  exit 0
fi

# Check if settings file exists
if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo "Warning: settings.json not found at $SETTINGS_FILE" >&2
  exit 0
fi

# Extract deny patterns from settings.json
# Format: "Bash(pattern:*)" -> "pattern *" (convert : to space for glob matching)
deny_patterns=$(jq -r '.permissions.deny[] // empty | select(startswith("Bash(")) | gsub("^Bash\\("; "") | gsub("\\)$"; "") | gsub(":"; " ")' "$SETTINGS_FILE" 2>/dev/null || echo "")

if [[ -z "$deny_patterns" ]]; then
  exit 0
fi

# Function to check if a command matches any deny pattern
check_command() {
  local cmd="$1"
  # Trim leading/trailing whitespace
  cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [[ -z "$cmd" ]]; then
    return 0
  fi

  while IFS= read -r pattern; do
    if [[ -z "$pattern" ]]; then
      continue
    fi
    # Use glob pattern matching
    # shellcheck disable=SC2053
    if [[ "$cmd" == $pattern ]] || [[ "$cmd" == $pattern* ]]; then
      echo "DENIED: Command '$cmd' matches deny pattern '$pattern'" >&2
      return 1
    fi
  done <<< "$deny_patterns"

  return 0
}

# Split command by logical operators and check each segment
# Handle: ; && ||
check_all_segments() {
  local full_command="$1"

  # Replace logical operators with newlines for processing
  # Be careful not to replace operators inside quoted strings
  local segments
  segments=$(echo "$full_command" | sed 's/[;]/ \n /g' | sed 's/&&/ \n /g' | sed 's/||/ \n /g')

  while IFS= read -r segment; do
    segment=$(echo "$segment" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$segment" ]]; then
      continue
    fi
    if ! check_command "$segment"; then
      return 1
    fi
  done <<< "$segments"

  return 0
}

# Perform the check
if ! check_all_segments "$command"; then
  exit 2
fi

exit 0
