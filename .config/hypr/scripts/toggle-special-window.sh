#!/usr/bin/env bash

set -euo pipefail

current_workspace="$({
  hyprctl -j activewindow 2>/dev/null || true
} | python3 -c 'import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit

workspace = data.get("workspace") or {}
print(workspace.get("name", ""))
')"

if [[ -z "$current_workspace" ]]; then
  exit 0
fi

if [[ "$current_workspace" == special:* ]]; then
  target_workspace="$({
    hyprctl -j monitors 2>/dev/null || true
  } | python3 -c 'import json, sys
try:
    monitors = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit

focused = next((monitor for monitor in monitors if monitor.get("focused")), monitors[0] if monitors else {})
workspace = focused.get("activeWorkspace") or {}
name = str(workspace.get("name", ""))

if name and not name.startswith("special:"):
    print(name)
    raise SystemExit

workspace_id = workspace.get("id")
if isinstance(workspace_id, int) and workspace_id > 0:
    print(workspace_id)
else:
    print("")
')"

  if [[ -z "$target_workspace" ]]; then
    exit 1
  fi

  hyprctl dispatch movetoworkspacesilent "$target_workspace"
  hyprctl dispatch togglespecialworkspace magic
  exit 0
fi

hyprctl dispatch movetoworkspacesilent special:magic
