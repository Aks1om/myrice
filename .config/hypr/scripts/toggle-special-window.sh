#!/usr/bin/env bash

set -euo pipefail

# On Hyprland's Lua configuration, `hyprctl dispatch` expects Lua expressions,
# not the old text dispatcher syntax. Select the window by address so focus
# changes between the query and the move cannot send another window away.
read -r address current_workspace < <(hyprctl -j activewindow | python3 -c 'import json, sys
window = json.load(sys.stdin)
print(window.get("address", ""), (window.get("workspace") or {}).get("name", ""))
')
[[ "$address" =~ ^0x[0-9a-fA-F]+$ && -n "$current_workspace" ]] || exit 0

if [[ "$current_workspace" == special:magic ]]; then
  target_workspace=$(hyprctl -j monitors | python3 -c 'import json, sys
monitors = json.load(sys.stdin)
monitor = next((m for m in monitors if m.get("focused")), None)
print((monitor or {}).get("activeWorkspace", {}).get("id", ""))
')
  [[ "$target_workspace" =~ ^[1-9][0-9]*$ ]] || exit 1
else
  target_workspace=special:magic
  was_visible=$(hyprctl -j monitors | python3 -c 'import json, sys
print(any((m.get("specialWorkspace") or {}).get("name") == "special:magic" for m in json.load(sys.stdin)))
')
fi

hyprctl eval "hl.dispatch(hl.dsp.focus({ window = 'address:$address' })); hl.dispatch(hl.dsp.window.move({ workspace = '$target_workspace' }))"

if [[ "$current_workspace" == special:magic ]]; then
  # Close an empty special workspace, but leave it open for any other windows.
  if ! hyprctl -j clients | python3 -c 'import json, sys
sys.exit(0 if any((c.get("workspace") or {}).get("name") == "special:magic" for c in json.load(sys.stdin)) else 1)
' && hyprctl -j monitors | python3 -c 'import json, sys
sys.exit(0 if any((m.get("specialWorkspace") or {}).get("name") == "special:magic" for m in json.load(sys.stdin)) else 1)
'; then
    hyprctl eval "hl.dispatch(hl.dsp.workspace.toggle_special('magic'))"
  fi
elif [[ "$was_visible" == False ]]; then
  # Lua's move follows the window into the special workspace; hide it again.
  hyprctl eval "hl.dispatch(hl.dsp.workspace.toggle_special('magic'))"
fi
