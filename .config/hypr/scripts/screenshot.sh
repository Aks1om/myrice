#!/usr/bin/env bash

set -euo pipefail

DIR="${HOME}/Pictures/Screenshots"
mkdir -p "${DIR}"
FILE="${DIR}/$(date +%Y-%m-%d_%H-%M-%S).png"

MODE="${1:-area}"

if [[ "${MODE}" == "output" ]]; then
  grim "${FILE}"
else
  grim -g "$(slurp)" "${FILE}"
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send "Screenshot saved" "${FILE}"
fi
