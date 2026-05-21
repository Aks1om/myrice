#!/bin/bash
# Lock/unlock встроенной клавы и тачпада ноутбука.
# Usage: lock-input.sh [lock|unlock|toggle]

KB="at-translated-set-2-keyboard"
TP="pnp0c50:03-36b6:c001-touchpad"
STATE="/tmp/hypr-input-locked"

action="${1:-toggle}"
if [ "$action" = "toggle" ]; then
    [ -f "$STATE" ] && action="unlock" || action="lock"
fi

case "$action" in
    lock)
        hyprctl keyword "device[$KB]:enabled" false >/dev/null
        hyprctl keyword "device[$TP]:enabled" false >/dev/null
        touch "$STATE"
        notify-send -t 2000 -i input-keyboard "Input locked" "Внутренняя клава и тачпад выключены"
        ;;
    unlock)
        hyprctl keyword "device[$KB]:enabled" true >/dev/null
        hyprctl keyword "device[$TP]:enabled" true >/dev/null
        rm -f "$STATE"
        notify-send -t 2000 -i input-keyboard "Input unlocked" "Внутренняя клава и тачпад включены"
        ;;
    *)
        echo "Usage: $0 [lock|unlock|toggle]" >&2
        exit 1
        ;;
esac
