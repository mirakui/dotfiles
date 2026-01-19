#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

zsh_file="${ROOT_DIR}/zsh/ai-cmd.zsh"

if [[ ! -f "$zsh_file" ]]; then
  echo "missing: $zsh_file" >&2
  exit 1
fi

out="$(zsh -fc "source '${zsh_file}'; _ai_cmd_insert_apply 'echo ' ' | cat' 'HELLO'")"
buf="$(printf '%s\n' "$out" | sed -n '1p')"
cursor="$(printf '%s\n' "$out" | sed -n '2p')"

[[ "$buf" == "echo HELLO | cat" ]] || { echo "expected buffer to be 'echo HELLO | cat' but got: $buf" >&2; exit 1; }
[[ "$cursor" == "10" ]] || { echo "expected cursor to be 10 but got: $cursor" >&2; exit 1; }

out2="$(zsh -fc "source '${zsh_file}'; _ai_cmd_insert_apply '' '' \$'A\nB\rC'")"
buf2="$(printf '%s\n' "$out2" | sed -n '1p')"
cursor2="$(printf '%s\n' "$out2" | sed -n '2p')"

[[ "$buf2" == "A B C" ]] || { echo "expected newlines to be sanitized to spaces but got: $buf2" >&2; exit 1; }
[[ "$cursor2" == "5" ]] || { echo "expected cursor to be 5 but got: $cursor2" >&2; exit 1; }

echo "ok"
