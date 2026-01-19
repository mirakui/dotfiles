# ai-cmd zle widget: insert generated command into the current prompt line.

# Sanitize arbitrary text into a single line (avoid breaking prompt display).
function _ai_cmd_sanitize_single_line() {
  emulate -L zsh
  setopt localoptions noshwordsplit

  local s="${1-}"
  s="${s//$'\r'/ }"
  s="${s//$'\n'/ }"
  # Collapse consecutive spaces for nicer UX
  s="${s//  / }"
  print -r -- "$s"
}

# Pure helper for tests: given left/right buffers and inserted text, output:
# 1st line: new buffer
# 2nd line: new cursor position
function _ai_cmd_insert_apply() {
  emulate -L zsh
  setopt localoptions noshwordsplit

  local lbuf="${1-}"
  local rbuf="${2-}"
  local ins="$(_ai_cmd_sanitize_single_line "${3-}")"

  local newbuf="${lbuf}${ins}${rbuf}"
  local newcursor=$(( ${#lbuf} + ${#ins} ))
  print -r -- "$newbuf"
  print -r -- "$newcursor"
}

# zle widget: prompt for a natural language request, run ai-cmd, and insert output.
function ai-cmd-insert() {
  emulate -L zsh
  setopt localoptions noshwordsplit

  if (( ! $+commands[ai-cmd] )); then
    zle -M "ai-cmd not found"
    return 127
  fi

  local nl=""
  vared -p "ai-cmd> " nl
  nl="$(_ai_cmd_sanitize_single_line "$nl")"

  if [[ -z "$nl" ]]; then
    zle redisplay
    return 0
  fi

  local out status
  out="$(command ai-cmd -- "$nl" 2>&1)"
  status=$?
  out="$(_ai_cmd_sanitize_single_line "$out")"

  if (( status != 0 )); then
    zle -M "ai-cmd failed: ${out}"
    return $status
  fi

  BUFFER="${LBUFFER}${out}${RBUFFER}"
  CURSOR=$(( ${#LBUFFER} + ${#out} ))
  zle redisplay
}
