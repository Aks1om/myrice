#!/usr/bin/env bash
set -uo pipefail

bus_get() {
  busctl --json=short get-property org.bluez "$1" "$2" "$3" 2>/dev/null | jq -r '.data // empty'
}

emit() {
  local text="$1" tooltip="$2" class="$3"
  tooltip="${tooltip//$'\n'/\\n}"
  printf '{"text":"%s","tooltip":"%s","class":"%s","alt":"%s"}\n' "$text" "$tooltip" "$class" "$class"
}

label_from_hci() {
  local hci="$1"
  local sys="/sys/class/bluetooth/$hci/device"
  [[ -d "$sys" ]] || { printf 'BT'; return; }
  local v p
  v=$(cat "$sys/../idVendor" 2>/dev/null || echo "")
  p=$(cat "$sys/../idProduct" 2>/dev/null || echo "")
  case "${v}:${p}" in
    "0bda:a728") printf 'Dongle 5.4' ;;
    "13d3:3558") printf 'Built-in' ;;
    *)
      local pn
      pn=$(cat "$sys/../product" 2>/dev/null || echo "")
      if [[ -n "$pn" ]]; then
        printf '%s' "${pn% }"
      else
        printf '%s:%s' "$v" "$p"
      fi
      ;;
  esac
}

# 1. Determine default adapter MAC
default_mac=$(bluetoothctl list 2>/dev/null | awk '/\[default\]/ {print $2; exit}')
if [[ -z "${default_mac:-}" ]]; then
  emit ' off' 'No Bluetooth controller' 'off'
  exit 0
fi

# 2. Match MAC to hci path
hci_path=""
mapfile -t adapters < <(busctl tree org.bluez 2>/dev/null | grep -oE '/org/bluez/hci[0-9]+' | sort -u)
for adapter in "${adapters[@]}"; do
  addr=$(bus_get "$adapter" org.bluez.Adapter1 Address)
  if [[ "$addr" == "$default_mac" ]]; then
    hci_path="$adapter"
    break
  fi
done
hci_name="${hci_path##*/}"  # e.g. hci2

label=$(label_from_hci "$hci_name")

# 3. Powered?
powered=$(bus_get "$hci_path" org.bluez.Adapter1 Powered)
if [[ "$powered" != "true" ]]; then
  emit " $label off" "Adapter: $label"$'\n'"MAC: $default_mac"$'\n'"Not powered" 'off'
  exit 0
fi

# 4. Connected devices on this adapter
conn_name=""
conn_count=0
mapfile -t devs < <(busctl tree org.bluez 2>/dev/null | grep -oE "/org/bluez/$hci_name/dev_[A-F0-9_]+" | sort -u)
for dev in "${devs[@]}"; do
  c=$(bus_get "$dev" org.bluez.Device1 Connected)
  if [[ "$c" == "true" ]]; then
    conn_count=$((conn_count + 1))
    if [[ -z "$conn_name" ]]; then
      conn_name=$(bus_get "$dev" org.bluez.Device1 Alias)
    fi
  fi
done

if (( conn_count > 0 )); then
  emit " $label · $conn_name" "Adapter: $label"$'\n'"MAC: $default_mac"$'\n'"Connected: $conn_name" 'connected'
else
  emit " $label" "Adapter: $label"$'\n'"MAC: $default_mac"$'\n'"No connections" 'on'
fi
