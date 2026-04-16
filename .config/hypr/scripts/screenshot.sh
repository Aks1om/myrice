#!/usr/bin/env bash

set -euo pipefail

DIR="${HOME}/Pictures/Screenshots"
mkdir -p "${DIR}"
FILE="${DIR}/$(date +%Y-%m-%d_%H-%M-%S).png"

MODE="${1:-menu}"

if [[ "${MODE}" == "menu" ]]; then
  menu_input='Area
Window
Screen
'

  if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wofi >/dev/null 2>&1; then
    choice="$(printf '%s' "${menu_input}" | wofi --dmenu --prompt 'screenshot' \
      --width 360 --height 175 --location center --hide-search --hide-scroll \
      --style "$HOME/.config/wofi/screenshot.css" || true)"
  elif command -v rofi >/dev/null 2>&1; then
    choice="$(printf '%s' "${menu_input}" | rofi -dmenu -i -p 'screenshot' || true)"
  elif command -v fuzzel >/dev/null 2>&1; then
    choice="$(printf '%s' "${menu_input}" | fuzzel --dmenu --prompt 'screenshot' || true)"
  else
    choice="Area"
  fi

  case "${choice}" in
    Area) MODE="area" ;;
    Window) MODE="window" ;;
    Screen) MODE="output" ;;
    *) exit 0 ;;
  esac
fi

if command -v hyprshot >/dev/null 2>&1; then
  case "${MODE}" in
    area)
      hyprshot -m region -z -o "${DIR}" -f "$(basename "${FILE}")"
      ;;
    window)
      hyprshot -m window -z -o "${DIR}" -f "$(basename "${FILE}")"
      ;;
    output)
      hyprshot -m output -z -o "${DIR}" -f "$(basename "${FILE}")"
      ;;
    *)
      exit 1
      ;;
  esac

  exit 0
fi

if [[ "${MODE}" == "output" ]]; then
  grim "${FILE}"
elif [[ "${MODE}" == "window" ]]; then
  grim -g "$(slurp)" "${FILE}"
else
  grim -g "$(slurp)" "${FILE}"
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send "Screenshot saved" "${FILE}"
fi
