#!/usr/bin/env bash

set -euo pipefail

monitors_json="$(hyprctl -j monitors 2>/dev/null || printf '[]')"
clients_json="$(hyprctl -j clients 2>/dev/null || printf '[]')"

python3 - "$monitors_json" "$clients_json" <<'PY'
import json
import sys

SPECIAL_NAME = "special:magic"

try:
    monitors = json.loads(sys.argv[1])
except Exception:
    monitors = []

try:
    clients = json.loads(sys.argv[2])
except Exception:
    clients = []

visible = any((monitor.get("specialWorkspace") or {}).get("name") == SPECIAL_NAME for monitor in monitors)
occupied = any(((client.get("workspace") or {}).get("name") == SPECIAL_NAME) and client.get("mapped") for client in clients)

if visible:
    text = "◆"
    tooltip = "Secret workspace is open"
    css_class = "active"
elif occupied:
    text = "◆"
    tooltip = "Secret workspace has hidden windows"
    css_class = "occupied"
else:
    text = "◆"
    tooltip = "Secret workspace is empty"
    css_class = "empty"

print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class}))
PY
