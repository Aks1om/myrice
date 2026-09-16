#!/usr/bin/env bash
# Single wallpaper backend for static images and video files.
set -euo pipefail

readonly WALLPAPER_DIRS=("$HOME/wallpaper" "$HOME/Pictures/Wallpapers")
readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/myrice"
readonly SELECTION_FILE="$STATE_DIR/wallpaper-selection"
readonly STATIC_LINK="$HOME/.local/share/hyprpaper/current-wallpaper"

is_video() {
  case "${1,,}" in
    *.mp4|*.webm|*.mkv|*.avi|*.mov|*.gif|*.webp) return 0 ;;
    *) return 1 ;;
  esac
}

is_wallpaper() {
  case "${1,,}" in
    *.jpg|*.jpeg|*.png|*.bmp|*.avif|*.mp4|*.webm|*.mkv|*.avi|*.mov|*.gif|*.webp) return 0 ;;
    *) return 1 ;;
  esac
}

stop_backends() {
  pkill -x hyprpaper 2>/dev/null || true
  pkill -x mpvpaper 2>/dev/null || true
}

save_selection() {
  local type=$1 path=$2
  install -d -m 700 "$STATE_DIR"
  printf '%s\n%s\n' "$type" "$path" >"$SELECTION_FILE"
}

start_image() {
  local path=$1
  stop_backends
  install -d -m 700 "${STATIC_LINK%/*}"
  ln -sfn "$path" "$STATIC_LINK"
  hyprpaper >/dev/null 2>&1 &
}

start_video() {
  local path=$1 output
  stop_backends
  while IFS= read -r output; do
    mpvpaper --fork --auto-pause --auto-mode full \
      --mpv-options "no-audio loop-file=inf fps=30" \
      "$output" "$path" >/dev/null 2>&1
  done < <(hyprctl -j monitors | jq -r '.[] | select(.disabled | not) | .name')
}

apply() {
  local path=$1 type
  [ -f "$path" ] || { printf 'Wallpaper file not found: %s\n' "$path" >&2; return 1; }
  is_wallpaper "$path" || { printf 'Unsupported wallpaper type: %s\n' "$path" >&2; return 2; }

  if is_video "$path"; then
    type=video
    start_video "$path"
  else
    type=image
    start_image "$path"
  fi
  save_selection "$type" "$path"
}

restore() {
  local type path
  if [ -r "$SELECTION_FILE" ]; then
    {
      IFS= read -r type
      IFS= read -r path
    } <"$SELECTION_FILE"
    if [ -f "$path" ]; then
      case "$type" in
        image) start_image "$path" ;;
        video) start_video "$path" ;;
        *) printf 'Invalid wallpaper selection type: %s\n' "$type" >&2; return 1 ;;
      esac
      return 0
    fi
  fi

  [ -e "$STATIC_LINK" ] && start_image "$(readlink -f "$STATIC_LINK")"
}

list() {
  local directory path
  local -a paths=()
  shopt -s nullglob
  for directory in "${WALLPAPER_DIRS[@]}"; do
    for path in "$directory"/*; do
      [ -f "$path" ] && is_wallpaper "$path" && paths+=("$path")
    done
  done
  jq -n --args '
    $ARGS.positional | map({
      path: ., name: (split("/") | last),
      type: (if test("\\.(mp4|webm|mkv|avi|mov|gif|webp)$"; "i") then "video" else "image" end)
    })
  ' "${paths[@]}"
}

case "${1:-}" in
  list) [ "$#" -eq 1 ] || exit 2; list ;;
  apply) [ "$#" -eq 2 ] || exit 2; apply "$2" ;;
  restore) [ "$#" -eq 1 ] || exit 2; restore ;;
  *) printf 'Usage: %s {list|apply <file>|restore}\n' "${0##*/}" >&2; exit 2 ;;
esac
