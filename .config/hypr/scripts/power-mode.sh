#!/usr/bin/env bash
# Manual-only display backlight mode. It never changes refresh rate, PPD, GPU,
# compositor, terminal, Wi-Fi, or idle settings.
set -u

STATE_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/power-mode"
MODE_FILE="$STATE_DIR/mode"
BRIGHTNESS_FILE="$STATE_DIR/brightness"
LEGACY_MODE_FILE="$HOME/.cache/power-mode"

current_mode() {
    local mode
    mode=$(cat "$MODE_FILE" 2>/dev/null) || mode="normal"
    case "$mode" in
        battery|normal) printf '%s\n' "$mode" ;;
        # Migrate the previous three-state implementation without retaining it.
        performance|balanced|powersave) printf '%s\n' "normal" ;;
        *) printf '%s\n' "normal" ;;
    esac
}

legacy_powersave() {
    [[ $(cat "$LEGACY_MODE_FILE" 2>/dev/null) == "powersave" ]]
}

backlight_device() {
    local -a devices
    mapfile -t devices < <(brightnessctl -m -c backlight 2>/dev/null) || return 1
    [[ ${#devices[@]} -eq 1 ]] || return 1
    IFS=, read -r REPLY _ <<< "${devices[0]}"
    [[ -n "$REPLY" ]] || return 1
    printf '%s\n' "$REPLY"
}

write_state() {
    mkdir -p "$STATE_DIR" || return 1
    printf '%s\n' "$1" > "$MODE_FILE"
}

restore_legacy_residue() {
    local node
    for node in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [[ -w "$node" ]] && printf '%s\n' auto > "$node"
    done
    if command -v powerprofilesctl >/dev/null 2>&1 && [[ $(powerprofilesctl get 2>/dev/null) == "power-saver" ]]; then
        powerprofilesctl set balanced || return 1
    fi
}

set_battery() {
    local device brightness
    device=$(backlight_device) || {
        printf '%s\n' 'power-mode: exactly one writable built-in backlight is required' >&2
        return 1
    }
    brightness=$(brightnessctl -d "$device" get 2>/dev/null) || {
        printf '%s\n' 'power-mode: could not read built-in backlight' >&2
        return 1
    }
    [[ $brightness =~ ^[0-9]+$ ]] || return 1
    mkdir -p "$STATE_DIR" || return 1
    if [[ $(current_mode) != "battery" ]]; then
        printf '%s\n' "$brightness" > "$BRIGHTNESS_FILE" || return 1
    fi
    brightnessctl -d "$device" set 40% -q || {
        printf '%s\n' 'power-mode: could not set built-in backlight' >&2
        return 1
    }
    write_state battery
}

set_normal() {
    local device brightness
    if legacy_powersave; then
        restore_legacy_residue || {
            printf '%s\n' 'power-mode: could not remediate legacy powersave profile' >&2
            return 1
        }
    fi
    if [[ $(current_mode) == "battery" && -r "$BRIGHTNESS_FILE" ]]; then
        device=$(backlight_device) || {
            printf '%s\n' 'power-mode: exactly one writable built-in backlight is required' >&2
            return 1
        }
        brightness=$(<"$BRIGHTNESS_FILE")
        [[ $brightness =~ ^[0-9]+$ ]] || {
            printf '%s\n' 'power-mode: saved brightness is invalid' >&2
            return 1
        }
        brightnessctl -d "$device" set "$brightness" -q || {
            printf '%s\n' 'power-mode: could not restore built-in backlight' >&2
            return 1
        }
        rm -f "$BRIGHTNESS_FILE"
    fi
    write_state normal
}

report() {
    case "$(current_mode)" in
        battery) printf '%s\n' '{"text":"󰁹","class":"battery","tooltip":"Батарея: встроенная подсветка 40%"}' ;;
        *)       printf '%s\n' '{"text":"󰁹","class":"normal","tooltip":"Обычный режим"}' ;;
    esac
}

case "${1:-toggle}" in
    get) report ;;
    battery) set_battery ;;
    normal) set_normal ;;
    toggle)
        if [[ $(current_mode) == "battery" ]]; then set_normal; else set_battery; fi
        ;;
    *) printf '%s\n' "Usage: $0 {get|normal|battery|toggle}" >&2; exit 2 ;;
esac
