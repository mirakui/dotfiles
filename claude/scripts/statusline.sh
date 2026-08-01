#!/bin/bash

input=$(cat)
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty' 2>/dev/null)
model_name=$(echo "$input" | jq -r '.model.display_name')
username=$(whoami)
hostname=$(hostname -s)
if [[ "$current_dir" == "$HOME"* ]]; then
    display_dir="~${current_dir#"$HOME"}"
else
    display_dir="$current_dir"
fi
git_branch=""
if git --no-optional-locks -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git --no-optional-locks -C "$current_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi
context_pct=""
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')
    if [ "$current" != "null" ] && [ "$size" != "null" ] && [ "$size" -gt 0 ]; then
        pct=$((current * 100 / size))
        context_pct=" ${pct}%"
    fi
fi

# --- sandbox status ---
# Claude Code's statusLine input does not expose sandbox state, so we
# resolve it ourselves from the same settings files Claude Code reads,
# in the same precedence order (strongest first).
[ -z "$project_dir" ] && project_dir="$current_dir"

settings_files=(
    "/Library/Application Support/ClaudeCode/managed-settings.json"
    "$project_dir/.claude/settings.local.json"
    "$project_dir/.claude/settings.json"
    "$HOME/.claude/settings.json"
)

# Prints the value of a dotted key from the first settings file that
# actually defines it (precedence order). Uses getpath rather than
# `// empty` so an explicit `false` counts as set instead of falling
# through to a weaker file. Never lets jq errors leak to stderr;
# silently yields nothing (treated as "unset") on any failure.
find_setting() {
    local key="$1"
    local file val
    for file in "${settings_files[@]}"; do
        [ -f "$file" ] || continue
        val=$(jq -r --arg k "$key" \
            'getpath($k | split(".")) | if . == null then empty else tostring end' \
            "$file" 2>/dev/null)
        if [ -n "$val" ]; then
            printf '%s' "$val"
            return 0
        fi
    done
    return 1
}

sandbox_enabled=$(find_setting "sandbox.enabled" 2>/dev/null)
sandbox_auto_allow=$(find_setting "sandbox.autoAllowBashIfSandboxed" 2>/dev/null)

printf "%s@%s " "$username" "$hostname"
printf "\033[1;34m%s\033[0m" "$display_dir"
if [ -n "$git_branch" ]; then
    printf " \033[1;35mon %s\033[0m" "$git_branch"
fi
printf " \033[1;32m[%s]\033[0m" "$model_name"
if [ -n "$context_pct" ]; then
    printf " \033[1;33m%s\033[0m" "$context_pct"
fi
if [ "$sandbox_enabled" = "true" ]; then
    if [ "$sandbox_auto_allow" = "false" ]; then
        printf " \033[1;32m🔒 sandbox\033[0m"
    else
        printf " \033[1;32m🔒 sandbox:auto\033[0m"
    fi
else
    printf " \033[1;31m🔓 no-sandbox\033[0m"
fi

