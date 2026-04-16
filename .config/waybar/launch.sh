#!/usr/bin/env bash

set -euo pipefail

gdk_scale="${WAYBAR_GDK_SCALE:-}"
dpi_scale="${WAYBAR_DPI_SCALE:-}"

if [[ -z "$gdk_scale" && -z "$dpi_scale" ]] && command -v hyprctl >/dev/null 2>&1; then
  read -r gdk_scale dpi_scale <<<"$(hyprctl -j monitors 2>/dev/null | python3 -c 'import json, sys
try:
    monitors = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit

gdk = ""
dpi = ""
for monitor in monitors:
    width = int(monitor.get("width", 0) or 0)
    height = int(monitor.get("height", 0) or 0)
    name = str(monitor.get("name", "")).lower()
    is_internal = any(token in name for token in ("edp", "lvds"))
    if is_internal and (width >= 2800 or height >= 1800):
        gdk = "2"
        dpi = "1"
        break

if gdk:
    print(gdk, dpi)
else:
    print("")
')"
fi

if [[ -n "$gdk_scale" || -n "$dpi_scale" ]]; then
  : "${gdk_scale:=1}"
  : "${dpi_scale:=1}"
  GDK_SCALE="$gdk_scale" GDK_DPI_SCALE="$dpi_scale" exec waybar
fi

exec waybar
