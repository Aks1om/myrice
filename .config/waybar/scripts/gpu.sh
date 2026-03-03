#!/usr/bin/env bash

set -euo pipefail

json_out() {
  local text="$1"
  local tooltip="$2"
  local klass="$3"
  local perc="$4"
  printf '{"text":"%s","tooltip":"%s","class":"%s","percentage":%s}\n' "$text" "$tooltip" "$klass" "$perc"
}

if command -v nvidia-smi >/dev/null 2>&1; then
  util_raw="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | sed -n '1p' | tr -d ' ')"
  temp_raw="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | sed -n '1p' | tr -d ' ')"
  util="${util_raw:-0}"
  temp="${temp_raw:-0}"
  json_out "󰢮 ${util}%" "NVIDIA ${util}% | ${temp}C" "nvidia" "${util}"
  exit 0
fi

for busy in /sys/class/drm/card*/device/gpu_busy_percent; do
  if [[ -r "${busy}" ]]; then
    util="$(tr -d '[:space:]' < "${busy}")"
    temp=""
    for t in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
      if [[ -r "${t}" ]]; then
        temp="$(( $(tr -d '[:space:]' < "${t}") / 1000 ))"
        break
      fi
    done
    if [[ -n "${temp}" ]]; then
      json_out "󰢮 ${util}%" "GPU ${util}% | ${temp}C" "amd" "${util}"
    else
      json_out "󰢮 ${util}%" "GPU ${util}%" "amd" "${util}"
    fi
    exit 0
  fi
done

for freq in /sys/class/drm/card*/gt_cur_freq_mhz; do
  maxf="$(dirname "${freq}")/gt_max_freq_mhz"
  if [[ -r "${freq}" && -r "${maxf}" ]]; then
    cur="$(tr -d '[:space:]' < "${freq}")"
    max="$(tr -d '[:space:]' < "${maxf}")"
    if [[ "${max}" -gt 0 ]]; then
      util="$(( cur * 100 / max ))"
      json_out "󰢮 ${util}%" "Intel GPU ${cur}/${max} MHz" "intel" "${util}"
      exit 0
    fi
  fi
done

json_out "󰢮 --" "GPU metric unavailable" "unknown" "0"
