#!/usr/bin/env bash

set -euo pipefail

CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
RUNTIME_DIR="${CACHE_HOME}/frozen-screenshot"
FRAME="${RUNTIME_DIR}/frame.png"
WINDOW="${RUNTIME_DIR}/window.json"
SCREENSHOT_DIR="${HOME}/Pictures/Screenshots"

mkdir -p "${RUNTIME_DIR}" "${SCREENSHOT_DIR}"

save_result() {
  local file="$1"
  if [[ ! -s "${file}" ]] || [[ "$(od -An -tx1 -N8 "${file}" | tr -d '[:space:]')" != "89504e470d0a1a0a" ]]; then
    notify-send -u critical -a "Screenshot" "Screenshot failed" "No valid PNG image was saved." || true
    return 1
  fi

  if ! wl-copy --type image/png < "${file}"; then
    notify-send -u normal -a "Screenshot" "Clipboard copy failed" "Screenshot was saved to ${file}." || true
  fi

  notify-send "Screenshot saved" "${file}" -i "${file}" -a "Screenshot" || true
}

capture_frame() {
  local output temp_frame
  output="$(hyprctl -j monitors | jq -r '.[] | select(.focused).name')"
  temp_frame="${FRAME}.tmp.$$"
  grim -l 0 -o "${output}" "${temp_frame}"
  mv -f "${temp_frame}" "${FRAME}"
  hyprctl -j activewindow > "${WINDOW}"
}

new_file() {
  printf '%s/%s.png\n' "${SCREENSHOT_DIR}" "$(date +%Y-%m-%d_%H-%M-%S)"
}

crop_frame() {
  local x="$1" y="$2" width="$3" height="$4" file
  [[ "${x}" =~ ^[0-9]+$ && "${y}" =~ ^[0-9]+$ && "${width}" =~ ^[1-9][0-9]*$ && "${height}" =~ ^[1-9][0-9]*$ ]] || exit 2
  file="$(new_file)"
  magick "${FRAME}" -crop "${width}x${height}+${x}+${y}" +repage "${file}"
  save_result "${file}"
}

case "${1:-}" in
  open)
    capture_frame
    qs ipc call frozenScreenshot open
    ;;
  output)
    file="$(new_file)"
    cp "${FRAME}" "${file}"
    save_result "${file}"
    ;;
  window)
    [[ -s "${WINDOW}" ]] || exit 1
    read -r x y width height < <(jq -r '[.at[0], .at[1], .size[0], .size[1]] | @tsv' "${WINDOW}")
    crop_frame "${x}" "${y}" "${width}" "${height}"
    ;;
  area)
    crop_frame "${2:-}" "${3:-}" "${4:-}" "${5:-}"
    ;;
  *)
    exit 2
    ;;
esac
