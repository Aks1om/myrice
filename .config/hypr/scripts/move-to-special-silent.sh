#!/usr/bin/env bash
# Lua's move dispatcher follows the window into a special workspace. Hide it again
# unless it was already visible before the move.
set -euo pipefail

was_visible=$(hyprctl -j monitors | jq -e 'any(.[]; .specialWorkspace.name == "special:magic")' >/dev/null && printf true || printf false)
hyprctl eval "hl.dispatch(hl.dsp.window.move({ workspace = 'special:magic' }))" >/dev/null

if [ "$was_visible" = false ]; then
  hyprctl eval "hl.dispatch(hl.dsp.workspace.toggle_special('magic'))" >/dev/null
fi
