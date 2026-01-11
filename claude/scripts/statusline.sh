#!/bin/bash

input=$(cat)
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
username=$(whoami)
hostname=$(hostname -s)
if [[ "$current_dir" == "$HOME"* ]]; then
    display_dir="~${current_dir#$HOME}"
else
    display_dir="$current_dir"
fi
git_branch=""
if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git -C "$current_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
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
printf "%s@%s " "$username" "$hostname"
printf "\033[1;34m%s\033[0m" "$display_dir"
if [ -n "$git_branch" ]; then
    printf " \033[1;35mon %s\033[0m" "$git_branch"
fi
printf " \033[1;32m[%s]\033[0m" "$model_name"
if [ -n "$context_pct" ]; then
    printf " \033[1;33m%s\033[0m" "$context_pct"
fi

