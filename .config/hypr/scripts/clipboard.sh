#!/usr/bin/env bash

set -euo pipefail

theme="$HOME/.config/rofi/macos.rasi"

set +e
selection="$({
  cliphist list
} | rofi -dmenu -i -p 'Clipboard' -mesg 'Enter to copy | Delete to remove' -kb-custom-1 'Delete' -theme "$theme")"
status=$?
set -e

if [[ -z "$selection" ]]; then
  exit 0
fi

case "$status" in
  0)
    printf '%s\n' "$selection" | cliphist decode | wl-copy
    ;;
  10)
    printf '%s\n' "$selection" | cliphist delete
    ;;
  *)
    exit 0
    ;;
esac
