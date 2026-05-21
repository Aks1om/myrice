#!/usr/bin/env bash
# Switch PPD profile, monitor refresh rate, and backlight based on AC state.
# Idempotent: no-op if state hasn't changed since last run.
set -euo pipefail

LAST_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/power-mode-last"

ac_online=0
for f in /sys/class/power_supply/A{C,DP}*/online; do
  [[ -f "$f" ]] || continue
  ac_online=$(<"$f")
  break
done

force=0
[[ "${1:-}" == "--force" ]] && force=1

if [[ $force -eq 0 && -f "$LAST_STATE_FILE" && "$(<"$LAST_STATE_FILE")" == "$ac_online" ]]; then
  exit 0
fi
echo "$ac_online" > "$LAST_STATE_FILE"

MONITOR="eDP-1"
RES="3072x1920"
POS="0x0"

# Keep PPD on performance in both modes — user prefers responsive UI over battery.
# Battery saving comes only from refresh rate and brightness; CPU still idles
# down naturally via P-state when load is low.
PROFILE="performance"
if [[ "$ac_online" == "1" ]]; then
  HZ="120"
  BRIGHT="80%"
else
  HZ="60"
  BRIGHT="40%"
fi

powerprofilesctl set "$PROFILE" 2>/dev/null || true

# Only touch monitor if Hz actually needs to change; preserve current scale to
# avoid resetting user's UI scale on every AC event.
if command -v jq >/dev/null 2>&1; then
  read -r current_hz current_scale < <(
    hyprctl monitors -j 2>/dev/null \
      | jq -r --arg m "$MONITOR" '.[] | select(.name==$m) | "\(.refreshRate) \(.scale)"'
  ) || true
  # round Hz to integer for comparison (120.00200 -> 120)
  current_hz_int=${current_hz%%.*}
  if [[ "$current_hz_int" != "$HZ" && -n "$current_scale" ]]; then
    hyprctl keyword monitor "$MONITOR,$RES@$HZ,$POS,$current_scale" >/dev/null 2>&1 || true
  fi
fi

brightnessctl set "$BRIGHT" >/dev/null 2>&1 || true

logger -t power-mode "AC=$ac_online -> PPD=$PROFILE / ${HZ}Hz / brightness=$BRIGHT"
