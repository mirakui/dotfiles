---
name: wezterm-read-right-pane
description: Read the content of the right pane in WezTerm when Claude is running in the left pane.
---

# WezTerm Right Pane Reader

Use this skill when the user asks to read or summarize what is currently displayed in the right-side pane, while Claude is running in the left pane of the same WezTerm tab.

## Preconditions

- You are running inside WezTerm.
- The current pane is the left pane where Claude is running.
- The right pane is adjacent to the current pane.

## Steps

1. Get the pane id to the right of the current pane:

   `wezterm cli get-pane-direction right`

2. If no pane id is returned, report that there is no right-adjacent pane and stop.
3. Fetch the text from the right pane:

   `wezterm cli get-text --pane-id <PANE_ID>`

4. If you need a smaller range, add `--start-line` and `--end-line` to scope the capture.

## Command Examples

Get the right pane id and read its content:

`PANE_ID="$(wezterm cli get-pane-direction right)" && wezterm cli get-text --pane-id "$PANE_ID"`

List all panes to find the exact target:

`wezterm cli list --format json`

## Notes

- If the layout is complex (nested splits), "right" refers to the immediately adjacent pane. Use `wezterm cli list --format json` to identify the desired pane id by title or cwd.
- Use `--escapes` if you need to capture ANSI styling or color sequences; otherwise omit it for plain text.
