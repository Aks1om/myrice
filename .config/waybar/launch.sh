#!/usr/bin/env bash

set -euo pipefail

scale="${WAYBAR_SCALE:-}"

if [[ -z "$scale" ]] && command -v hyprctl >/dev/null 2>&1; then
  scale="$(hyprctl -j monitors 2>/dev/null | python3 -c 'import json, sys
try:
    monitors = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit

scale = ""
for monitor in monitors:
    width = int(monitor.get("width", 0) or 0)
    height = int(monitor.get("height", 0) or 0)
    name = str(monitor.get("name", "")).lower()
    is_internal = any(token in name for token in ("edp", "lvds"))
    if is_internal and (width >= 2800 or height >= 1800):
        scale = "1.35"
        break

print(scale)
')"
fi

if [[ -n "$scale" ]]; then
  GDK_SCALE=1 GDK_DPI_SCALE="$scale" exec waybar
fi

exec waybar
