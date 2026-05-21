#!/bin/bash

STATE_FILE="$HOME/.cache/power-mode"
BLUR_FILE="$HOME/.cache/power-mode-blur"
CURRENT=$(cat "$STATE_FILE" 2>/dev/null || echo "performance")

MONITOR="eDP-1"
RESOLUTION="3072x1920"
SCALE="1.2"

set_performance() {
    echo "performance" > "$STATE_FILE"

    hyprctl keyword monitor "$MONITOR,$RESOLUTION@120,auto,$SCALE"
    brightnessctl set 100%

    BLUR_STATE=$(cat "$BLUR_FILE" 2>/dev/null || echo "1")
    hyprctl keyword decoration:blur:enabled "$BLUR_STATE"

    echo "auto" | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level > /dev/null 2>&1
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        echo "balance_performance" | sudo tee "$cpu" > /dev/null 2>&1
    done

    notify-send -i battery-full "Режим питания" "Максимальная производительность (120Hz)" -t 2000
}

set_balanced() {
    echo "balanced" > "$STATE_FILE"

    hyprctl keyword monitor "$MONITOR,$RESOLUTION@60,auto,$SCALE"
    brightnessctl set 100%

    BLUR_STATE=$(cat "$BLUR_FILE" 2>/dev/null || echo "1")
    hyprctl keyword decoration:blur:enabled "$BLUR_STATE"

    echo "auto" | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level > /dev/null 2>&1
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        echo "balance_performance" | sudo tee "$cpu" > /dev/null 2>&1
    done

    notify-send -i battery "Режим питания" "Сбалансированный (60Hz)" -t 2000
}

set_powersave() {
    echo "powersave" > "$STATE_FILE"

    # Сохраняем состояние blur только при первом входе в powersave
    if [[ "$CURRENT" != "powersave" ]]; then
        hyprctl -j getoption decoration:blur:enabled \
            | python3 -c "import sys,json; print(json.load(sys.stdin)['int'])" \
            > "$BLUR_FILE" 2>/dev/null
    fi

    hyprctl keyword monitor "$MONITOR,$RESOLUTION@60,auto,$SCALE"
    brightnessctl set 40%
    hyprctl keyword decoration:blur:enabled false

    echo "low" | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level > /dev/null 2>&1
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        echo "power" | sudo tee "$cpu" > /dev/null 2>&1
    done

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
