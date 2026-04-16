#!/usr/bin/env bash

set -euo pipefail

device="$(nmcli -t -f DEVICE,TYPE device status | while IFS=: read -r dev type; do
  if [[ "$type" == "wifi" ]]; then
    printf '%s\n' "$dev"
    break
  fi
done)"

if [[ -z "$device" ]]; then
  notify-send "Wi-Fi" "Wi-Fi device not found"
  exit 1
fi

radio_state="$(nmcli radio wifi)"
declare -a entries=()
declare -a kinds=()
declare -a ssids=()
declare -A security_map=()

if [[ "$radio_state" == "enabled" ]]; then
  entries+=("Disable Wi-Fi" "Disconnect" "Rescan")
  kinds+=("disable" "disconnect" "rescan")
  ssids+=("" "" "")
else
  entries+=("Enable Wi-Fi")
  kinds+=("enable")
  ssids+=("")
fi

if [[ "$radio_state" == "enabled" ]]; then
  declare -A seen=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    in_use="${line%%:*}"
    rest="${line#*:}"
    security="${rest##*:}"
    before_security="${rest%:*}"
    signal="${before_security##*:}"
    ssid="${before_security%:*}"

    ssid="${ssid//\\:/:}"
    ssid="${ssid//\\\\/\\}"

    if [[ -z "$ssid" ]]; then
      ssid="<hidden>"
    fi

    if [[ -n "${seen[$ssid]:-}" ]]; then
      continue
    fi
    seen[$ssid]=1
    security_map["$ssid"]="$security"

    state="open"
    if [[ -n "$security" && "$security" != "--" ]]; then
      state="secured"
    fi
    if [[ "$in_use" == "*" ]]; then
      state="connected"
    fi

    entries+=("${state}  ${signal}%  ${ssid}")
    kinds+=("network")
    ssids+=("$ssid")
  done < <(nmcli -t --escape yes -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan auto)
fi

choice_index="$(printf '%s\n' "${entries[@]}" | rofi -dmenu -i -p "wifi" -format i -theme "$HOME/.config/rofi/macos.rasi" || true)"

if [[ -z "$choice_index" ]]; then
  exit 0
fi

kind="${kinds[$choice_index]}"
ssid="${ssids[$choice_index]}"

case "$kind" in
  enable)
    nmcli radio wifi on
    notify-send "Wi-Fi" "Wi-Fi enabled"
    exit 0
    ;;
  disable)
    nmcli radio wifi off
    notify-send "Wi-Fi" "Wi-Fi disabled"
    exit 0
    ;;
  disconnect)
    nmcli device disconnect "$device" >/dev/null 2>&1 || true
    notify-send "Wi-Fi" "Disconnected"
    exit 0
    ;;
  rescan)
    nmcli device wifi rescan ifname "$device"
    exec "$0"
    ;;
esac

if [[ "$ssid" == "<hidden>" ]]; then
  notify-send "Wi-Fi" "Hidden networks are not handled in this menu"
  exit 0
fi

if nmcli --wait 15 device wifi connect "$ssid" ifname "$device" >/dev/null 2>&1; then
  notify-send "Wi-Fi" "Connected to $ssid"
  exit 0
fi

security="${security_map[$ssid]:---}"
if [[ -n "$security" && "$security" != "--" ]]; then
  password="$(rofi -dmenu -password -p "password" -theme "$HOME/.config/rofi/macos.rasi" || true)"

  if [[ -z "$password" ]]; then
    exit 0
  fi

  if nmcli --wait 20 device wifi connect "$ssid" password "$password" ifname "$device" >/dev/null 2>&1; then
    notify-send "Wi-Fi" "Connected to $ssid"
    exit 0
  fi
fi

notify-send "Wi-Fi" "Failed to connect to $ssid"
exit 1
