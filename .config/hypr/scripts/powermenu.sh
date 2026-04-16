#!/usr/bin/env bash

set -euo pipefail

pick() {
  rofi -dmenu -i -p "power" -theme "$HOME/.config/rofi/power.rasi"
}

choice=$(printf "lock\nlogout\nreboot\nshutdown" | pick || true)

case "${choice}" in
  lock)
    hyprlock
    ;;
  logout)
    hyprctl dispatch exit
    ;;
  reboot)
    systemctl reboot
    ;;
  shutdown)
    systemctl poweroff
    ;;
  *)
    exit 0
    ;;
esac
