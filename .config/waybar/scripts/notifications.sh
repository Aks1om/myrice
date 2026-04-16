#!/usr/bin/env bash

set -euo pipefail

count="$(swaync-client -c -sw 2>/dev/null || printf '0')"
dnd="$(swaync-client -D -sw 2>/dev/null || printf 'false')"

count="${count//[^0-9]/}"
count="${count:-0}"

if [[ "$dnd" == "true" ]]; then
  text="󰂛"
  tooltip="Do Not Disturb"
  class="dnd"
elif (( count > 0 )); then
  text="󰂚 ${count}"
  tooltip="${count} unread notifications"
  class="has-notifications"
else
  text="󰂚"
  tooltip="Notifications"
  class="idle"
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$class"
