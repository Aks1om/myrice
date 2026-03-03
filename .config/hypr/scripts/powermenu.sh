#!/usr/bin/env bash

set -euo pipefail

choice=$(printf "lock\nlogout\nreboot\nshutdown" | rofi -dmenu -p "power")

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
