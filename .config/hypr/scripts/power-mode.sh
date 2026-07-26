#!/bin/bash

STATE_FILE="$HOME/.cache/power-mode"
MONITOR="eDP-1"
RESOLUTION="3072x1920"

CURRENT=$(cat "$STATE_FILE" 2>/dev/null || echo "performance")
GHOSTTY_CONF="$HOME/.config/ghostty/power-mode.conf"

# Read scale live — so mode switches never clobber the user's current scale
scale() { hyprctl -j monitors | jq -r '.[] | select(.name == "'"$MONITOR"'") | .scale'; }

# Write ghostty overrides and reload all running instances
ghostty_apply() {
    echo "$1" > "$GHOSTTY_CONF"
    pkill -USR2 ghostty 2>/dev/null || true
}

set_performance() {
    echo "performance" > "$STATE_FILE"
    hyprctl keyword monitor "$MONITOR,$RESOLUTION@120,auto,$(scale)"
    hyprctl keyword decoration:blur:enabled true
    brightnessctl set 100% -q
    powerprofilesctl set performance
    echo "auto" | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level > /dev/null
    ghostty_apply ""
    notify-send -i battery-full "Режим питания" "Максимальная производительность (120Hz)" -t 2000
}

set_balanced() {
    echo "balanced" > "$STATE_FILE"
    hyprctl keyword monitor "$MONITOR,$RESOLUTION@60,auto,$(scale)"
    hyprctl keyword decoration:blur:enabled true
    brightnessctl set 100% -q
    powerprofilesctl set balanced
    echo "auto" | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level > /dev/null
    ghostty_apply ""
    notify-send -i battery "Режим питания" "Сбалансированный (60Hz)" -t 2000
}

set_powersave() {
    echo "powersave" > "$STATE_FILE"
    hyprctl keyword monitor "$MONITOR,$RESOLUTION@60,auto,$(scale)"
    hyprctl keyword decoration:blur:enabled false
    brightnessctl set 40% -q
    powerprofilesctl set power-saver
    echo "low" | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level > /dev/null
    ghostty_apply "background-opacity = 1.0
background-blur = false"
    notify-send -i battery-low "Режим питания" "Энергосбережение (60Hz, 40% яркость)" -t 2000
}

case "$1" in
    get)
        case "$CURRENT" in
            performance) echo '{"text":"󰁹","class":"performance","tooltip":"Максимальная производительность (120Hz)"}' ;;
            balanced)    echo '{"text":"󰁹","class":"balanced","tooltip":"Сбалансированный режим (60Hz)"}'              ;;
            powersave)   echo '{"text":"󰁹","class":"powersave","tooltip":"Энергосбережение (60Hz, 40% яркость)"}'      ;;
        esac
        ;;
    performance) set_performance ;;
    balanced)    set_balanced    ;;
    powersave)   set_powersave   ;;
    toggle|"")
        case "$CURRENT" in
            performance) set_balanced    ;;
            balanced)    set_powersave   ;;
            powersave)   set_performance ;;
        esac
        ;;
esac
