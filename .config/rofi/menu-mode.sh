#!/usr/bin/env bash
# Rofi script mode: quick-action menu items
# ROFI_RETV=0 -> initial item list
# ROFI_RETV=1 -> item selected

case "${ROFI_RETV:-0}" in
    0)
        printf "Files\nBluetooth\nNetwork\nSound\nLock\nPower\n"
        ;;
    1)
        case "$1" in
            "Files")     exec nemo ;;
            "Bluetooth") exec blueman-manager ;;
            "Network")   exec nm-connection-editor ;;
            "Sound")     exec pavucontrol ;;
            "Lock")      exec hyprlock ;;
            "Power")     exec ~/.config/hypr/scripts/powermenu.sh ;;
        esac
        ;;
esac
