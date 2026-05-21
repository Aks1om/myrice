#!/usr/bin/env bash
# Global UI scale — single knob for Waybar, Rofi, GTK/Qt apps, terminal.
# Per-monitor adaptive: snaps requested scale to each monitor's own valid set.
# Persists by rewriting only the scale column on existing monitor = lines.
#
# Usage:
#   scale.sh menu       # GTK slider + digit typing
#   scale.sh up|down    # ±5%
#   scale.sh reset      # 100%
#   scale.sh set 1.50   # exact request (will be snapped per monitor)

set -euo pipefail

CONF="$HOME/.config/hypr/monitors.conf"
MIN=0.80
MAX=2.50
STEP=0.05

current=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .scale')

# Snap requested scale to a Hyprland-valid value for given width/height.
# Wayland fractional rule: scale = k/120 where (w*120)%k == 0 AND (h*120)%k == 0.
snap_for() {
  local req="$1" w="$2" h="$3"
  awk -v req="$req" -v w="$w" -v h="$h" -v min="$MIN" -v max="$MAX" '
  BEGIN {
    minK=int(min*120); maxK=int(max*120+0.5)
    best=120; bestd=1e9
    for (k=minK; k<=maxK; k++) {
      if ((w*120) % k != 0) continue
      if ((h*120) % k != 0) continue
      s = k/120
      d = s-req; if (d<0) d=-d
      if (d<bestd) { bestd=d; best=s }
    }
    printf "%.10f", best
  }'
}

apply() {
  local req="$1"
  local pct
  # Apply live to every connected monitor with its own snapped scale.
  while IFS=$'\t' read -r name w h; do
    local s
    s="$(snap_for "$req" "$w" "$h")"
    hyprctl keyword monitor "${name},preferred,auto,${s}" >/dev/null
    # Persist: rewrite scale (last comma field) in matching monitor = line.
    # Matches lines targeting this monitor name OR the empty/default "," form.
    sed -i -E \
      -e "s|^(monitor\\s*=\\s*${name},[^,]+,[^,]+,)[0-9.]+\\s*$|\\1${s}|" \
      -e "s|^(monitor\\s*=\\s*${name},)[0-9.]+\\s*$|\\1${s}|" \
      "$CONF"
  done < <(hyprctl -j monitors | jq -r '.[] | "\(.name)\t\(.width)\t\(.height)"')

  # Fallback: update the generic "monitor = ,preferred,auto,SCALE" default line
  # (for setups using the wildcard monitor rule). Uses focused monitor's snap.
  read -r fw fh < <(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | "\(.width) \(.height)"')
  pct="$(snap_for "$req" "$fw" "$fh")"
  sed -i -E "s|^(monitor\\s*=\\s*,[^,]+,[^,]+,)[0-9.]+\\s*$|\\1${pct}|" "$CONF"

  hyprctl dismissnotify >/dev/null 2>&1 || true
  notify-send -t 1200 -h string:x-canonical-private-synchronous:scale \
    "Display scale" "$(awk -v v="$pct" 'BEGIN{printf "%.0f%%", v*100}')"
}

case "${1:-menu}" in
  up)    apply "$(awk -v c="$current" -v s="$STEP" 'BEGIN{print c+s}')" ;;
  down)  apply "$(awk -v c="$current" -v s="$STEP" 'BEGIN{print c-s}')" ;;
  reset) apply 1.00 ;;
  set)   apply "${2:?missing value}" ;;
  menu)
    val=$(awk -v c="$current" 'BEGIN{printf "%d", c*100+0.5}')
    new=$("$HOME/.config/hypr/scripts/scale-dialog.py" "$val") || exit 0
    apply "$(awk -v v="$new" 'BEGIN{printf "%.4f", v/100}')"
    ;;
  *) echo "usage: $0 {menu|up|down|reset|set <scale>}" >&2; exit 2 ;;
esac
