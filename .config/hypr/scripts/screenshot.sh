#!/usr/bin/env bash

set -euo pipefail

DIR="${HOME}/Pictures/Screenshots"
mkdir -p "${DIR}"
FILE="${DIR}/$(date +%Y-%m-%d_%H-%M-%S).png"

MODE="${1:-menu}"

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical -a "Screenshot" "Screenshot failed" "$1"
  fi
}

save_result() {
  if [[ ! -s "${FILE}" ]] || [[ "$(od -An -tx1 -N8 "${FILE}" | tr -d '[:space:]')" != "89504e470d0a1a0a" ]]; then
    notify_error "No valid PNG image was saved."
    return 1
  fi

  if command -v wl-copy >/dev/null 2>&1; then
    if ! wl-copy --type image/png < "${FILE}"; then
      notify_error "Saved to ${FILE}, but could not copy it to the clipboard."
      return 1
    fi
  fi

  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Screenshot" "Screenshot saved" "${FILE}" -i "${FILE}"
  fi
}

if [[ "${MODE}" == "menu" ]]; then
  menu_input='Area
Window
Screen
'

  if command -v rofi >/dev/null 2>&1; then
    choice="$(printf '%s' "${menu_input}" | ~/.config/hypr/scripts/rofi-popup.sh -dmenu -i -p 'screenshot' -theme "$HOME/.config/rofi/screenshot.rasi" || true)"
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

if [[ "${MODE}" == "area" ]]; then
  if ! command -v slurp >/dev/null 2>&1 || ! command -v grim >/dev/null 2>&1; then
    notify_error "slurp and grim are required to capture an area."
    exit 1
  fi

  if geometry="$(slurp)"; then
    :
  else
    status=$?
    if [[ "${status}" -eq 1 ]]; then
      exit 0
    fi
    notify_error "Could not start area selection."
    exit "${status}"
  fi

  if [[ -z "${geometry}" ]]; then
    exit 0
  fi

  if ! grim -l 0 -g "${geometry}" "${FILE}"; then
    notify_error "Could not capture the selected area."
    exit 1
  fi

  save_result
  exit $?
fi

if [[ "${MODE}" == "output" ]]; then
  grim -l 0 "${FILE}"
elif [[ "${MODE}" == "window" ]]; then
  grim -l 0 -g "$(slurp)" "${FILE}"
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send "Screenshot saved" "${FILE}"
fi
