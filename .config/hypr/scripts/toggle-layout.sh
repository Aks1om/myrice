#!/usr/bin/env bash

set -euo pipefail

keyboard="$(hyprctl -j devices | jq -r '.keyboards[] | select(.main == true) | .name')"

if [[ -z "$keyboard" || "$keyboard" == "null" ]]; then
  exit 1
fi

hyprctl switchxkblayout "$keyboard" next >/dev/null
