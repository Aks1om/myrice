#!/usr/bin/env bash
# Set the focused monitor's compositor scale and persist its exact monitor rule.
# Requested values are snapped to scales that produce an integer logical viewport.

set -euo pipefail

CONF="$HOME/.config/hypr/monitors.hl"
MIN=0.80
MAX=2.50

monitor_info() {
  hyprctl -j monitors | jq -r '
    .[] | select(.focused == true)
    | [.name, .width, .height, .refreshRate, .scale] | @tsv
  '
}

snap_for() {
  local requested="$1" width="$2" height="$3"

  awk -v req="$requested" -v w="$width" -v h="$height" -v min="$MIN" -v max="$MAX" '
    BEGIN {
      min_k = int(min * 120 + 0.5)
      max_k = int(max * 120 + 0.5)
      best_k = 120
      best_distance = 1e9

      for (k = min_k; k <= max_k; k++) {
        if ((w * 120) % k != 0 || (h * 120) % k != 0)
          continue

        scale = k / 120
        distance = scale - req
        if (distance < 0)
          distance = -distance

        if (distance < best_distance) {
          best_distance = distance
          best_k = k
        }
      }

      printf "%.10g", best_k / 120
    }
  '
}

adjacent_for() {
  local current="$1" direction="$2" width="$3" height="$4"

  awk -v current="$current" -v direction="$direction" -v w="$width" -v h="$height" -v min="$MIN" -v max="$MAX" '
    BEGIN {
      min_k = int(min * 120 + 0.5)
      max_k = int(max * 120 + 0.5)
      selected = current

      if (direction == "up") {
        for (k = min_k; k <= max_k; k++) {
          if ((w * 120) % k != 0 || (h * 120) % k != 0)
            continue
          scale = k / 120
          if (scale > current + 0.0001) {
            selected = scale
            break
          }
        }
      } else {
        for (k = max_k; k >= min_k; k--) {
          if ((w * 120) % k != 0 || (h * 120) % k != 0)
            continue
          scale = k / 120
          if (scale < current - 0.0001) {
            selected = scale
            break
          }
        }
      }

      printf "%.10g", selected
    }
  '
}

list_for() {
  local width="$1" height="$2"

  awk -v w="$width" -v h="$height" -v min="$MIN" -v max="$MAX" '
    BEGIN {
      min_k = int(min * 120 + 0.5)
      max_k = int(max * 120 + 0.5)

      for (k = min_k; k <= max_k; k++) {
        if ((w * 120) % k == 0 && (h * 120) % k == 0)
          printf "%.0f\n", (k / 120) * 100
      }
    }
  '
}

persist_rule() {
  local name="$1" mode="$2" scale="$3" tmp
  tmp="$(mktemp "${CONF}.XXXXXX")"

  awk -v name="$name" -v rule="monitor = ${name},${mode},auto,${scale}" '
    BEGIN { replaced = 0; inserted = 0 }
    {
      target = $0
      sub(/^[[:space:]]*monitor[[:space:]]*=[[:space:]]*/, "", target)
      split(target, fields, ",")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", fields[1])

      if (fields[1] == name) {
        if (!replaced)
          print rule
        replaced = 1
        next
      }

      if (!replaced && !inserted && fields[1] == "" && $0 ~ /^[[:space:]]*monitor[[:space:]]*=/) {
        print rule
        inserted = 1
      }

      print
    }
    END {
      if (!replaced && !inserted)
        print rule
    }
  ' "$CONF" > "$tmp"

  mv "$tmp" "$CONF"
}

apply() {
  local requested="$1" name width height refresh current scale mode requested_pct applied_pct

  [[ "$requested" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
    printf 'invalid scale: %s\n' "$requested" >&2
    exit 2
  }

  IFS=$'\t' read -r name width height refresh current <<< "$(monitor_info)"
  [[ -n "$name" ]] || {
    printf 'no focused monitor\n' >&2
    exit 1
  }

  scale="$(snap_for "$requested" "$width" "$height")"
  mode="${width}x${height}@$(awk -v rate="$refresh" 'BEGIN { printf "%.3f", rate }')"

  hyprctl keyword monitor "${name},${mode},auto,${scale}" >/dev/null
  persist_rule "$name" "$mode" "$scale"

  requested_pct="$(awk -v value="$requested" 'BEGIN { printf "%.0f", value * 100 }')"
  applied_pct="$(awk -v value="$scale" 'BEGIN { printf "%.0f", value * 100 }')"

  hyprctl dismissnotify >/dev/null 2>&1 || true
  if [[ "$requested_pct" == "$applied_pct" ]]; then
    notify-send -t 1200 -h string:x-canonical-private-synchronous:scale \
      "Display scale" "${applied_pct}%"
  else
    notify-send -t 1600 -h string:x-canonical-private-synchronous:scale \
      "Display scale" "Requested ${requested_pct}% -> applied ${applied_pct}%"
  fi

  printf '%s\n' "$applied_pct"
}

IFS=$'\t' read -r focused_name focused_width focused_height focused_refresh current <<< "$(monitor_info)"

case "${1:-menu}" in
  up)
    apply "$(adjacent_for "$current" up "$focused_width" "$focused_height")"
    ;;
  down)
    apply "$(adjacent_for "$current" down "$focused_width" "$focused_height")"
    ;;
  reset)
    apply 1.00
    ;;
  set)
    apply "${2:?missing value}"
    ;;
  list)
    list_for "$focused_width" "$focused_height"
    ;;
  menu)
    current_pct="$(awk -v value="$current" 'BEGIN { printf "%.0f", value * 100 }')"
    selected_pct=$("$HOME/.config/hypr/scripts/scale-dialog.py" "$current_pct") || exit 0
    apply "$(awk -v value="$selected_pct" 'BEGIN { printf "%.4f", value / 100 }')"
    ;;
  *)
    printf 'usage: %s {menu|up|down|reset|set <scale>|list}\n' "$0" >&2
    exit 2
    ;;
esac
