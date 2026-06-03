#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
zshrc="${ROOT_DIR}/zsh/.zshrc"

if [[ ! -f "$zshrc" ]]; then
  echo "missing: $zshrc" >&2
  exit 1
fi

############################################################
# 1. 履歴番号抽出ヘルパー (.zshrc 内の実装をそのまま取り出して検証)
############################################################
helper="$(sed -n '/^function _fzf_history_num_from_line/,/^}/p' "$zshrc")"
[[ -n "$helper" ]] || {
  echo "FAIL: _fzf_history_num_from_line not found in .zshrc" >&2
  exit 1
}

run_extract() {
  zsh -fc "${helper}"$'\n''_fzf_history_num_from_line "$1"' _ "$1"
}

got="$(run_extract '  123  echo foo')"
[[ "$got" == "123" ]] || { echo "FAIL extract spaces: expected 123 got [$got]" >&2; exit 1; }

got="$(run_extract "$(printf '   42\techo a\\necho b')")"
[[ "$got" == "42" ]] || { echo "FAIL extract tab/backslash: expected 42 got [$got]" >&2; exit 1; }

got="$(run_extract 'no-number-here')"
[[ -z "$got" ]] || { echo "FAIL extract none: expected empty got [$got]" >&2; exit 1; }

############################################################
# 2. 番号経由ロードは改行を保持し、リテラルの "\n" を壊さない
#    fzf-history は選んだ行から履歴番号を取り出し vi-fetch-history で
#    生の履歴 ($history[num]) を復元する。その生履歴の振る舞いを検証する。
#    対比として旧実装の fc -ln (history -n) はエスケープで \n リテラル化する。
############################################################
probe="$(zsh -f <<'ZEOF'
emulate -L zsh
fc -p "/tmp/fzf_hist_test_$$" >/dev/null 2>&1
print -rs 'echo single'
print -rs $'echo ml1\necho ml2'        # 実際の改行を含む複数行コマンド (履歴番号 2)
print -rs 'echo "lit \n keep"'         # リテラルの backslash-n  (履歴番号 3)
print -rs 'echo guard'                 # 最新エントリ ($history で最新が欠ける場合の緩衝)
# 新方式: 番号から生履歴を引く -> 実際の改行を保持
print -r -- "NEW2=${history[2]//$'\n'/<NL>}"
print -r -- "NEW3=${history[3]//$'\n'/<NL>}"
# 旧方式: fc -ln のエスケープ表示 (改行が \n リテラルになる)
print -r -- "OLD2=$(fc -ln 2 2)"
ZEOF
)"

grep -qxF 'NEW2=echo ml1<NL>echo ml2' <<<"$probe" || {
  echo "FAIL: multiline newline not preserved via history number" >&2
  echo "$probe" >&2
  exit 1
}
grep -qxF 'NEW3=echo "lit \n keep"' <<<"$probe" || {
  echo "FAIL: literal backslash-n must not be turned into a real newline" >&2
  echo "$probe" >&2
  exit 1
}
grep -qF 'OLD2=echo ml1\necho ml2' <<<"$probe" || {
  echo "FAIL: expected old fc -ln to escape the newline to a literal \\n" >&2
  echo "$probe" >&2
  exit 1
}

echo "ok"
