#!/usr/bin/env bash

set -euo pipefail

pick() {
  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && command -v wofi >/dev/null 2>&1; then
    wofi --dmenu --prompt "power" --width 320 --height 240 --location center --style "$HOME/.config/wofi/startmenu.css"
  elif command -v rofi >/dev/null 2>&1; then
    rofi -dmenu -i -p "power" -theme "$HOME/.config/rofi/macos.rasi"
  elif command -v wofi >/dev/null 2>&1; then
    wofi --dmenu --prompt "power" --width 320 --height 240 --location center --style "$HOME/.config/wofi/startmenu.css"
  else
    fuzzel --dmenu --prompt "power"
  fi
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
