#!/usr/bin/env bash

set -euo pipefail

readonly keymap_dir="$HOME/.config/hypr/keymaps"
readonly normal_keymap="$keymap_dir/us-ru.xkb"
readonly custom_keymap="$keymap_dir/us-ru-ctrl-latin.xkb"
readonly runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
readonly lock_file="$runtime_dir/hypr-ru-ctrl-latin.lock"

[[ -d "$runtime_dir" ]] || {
    printf 'Runtime directory недоступен: %s\n' "$runtime_dir" >&2
    exit 1
}

for file in "$normal_keymap" "$custom_keymap"; do
    [[ -r "$file" ]] || {
        printf 'Не найден keymap-файл: %s\n' "$file" >&2
        exit 1
    }
done

exec 9>"$lock_file"
flock 9

current_keymap="$(hyprctl getoption input:kb_file -j | jq -r '.str')"
keyboard_layouts="$(hyprctl -j devices | jq -r '.keyboards[] | [.name, .active_layout_index] | @tsv')"
if [[ "$current_keymap" == "$custom_keymap" ]]; then
    target="$normal_keymap"
    next_state="normal"
else
    target="$custom_keymap"
    next_state="custom"
fi

hyprctl keyword input:kb_file "$target" >/dev/null
while IFS=$'\t' read -r keyboard layout_index; do
    [[ -n "$keyboard" ]] || continue
    hyprctl switchxkblayout "$keyboard" "$layout_index" >/dev/null
done <<<"$keyboard_layouts"

active_keymap="$(hyprctl getoption input:kb_file -j | jq -r '.str')"
[[ "$active_keymap" == "$target" ]] || {
    printf 'Hyprland не подтвердил загрузку keymap-файла: %s\n' "$target" >&2
    exit 1
}

hyprctl notify 1 1200 'rgb(89b4fa)' "Русский Ctrl-режим: $next_state" >/dev/null
