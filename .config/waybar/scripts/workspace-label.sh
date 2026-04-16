#!/usr/bin/env bash

set -euo pipefail

monitors_json="$(hyprctl -j monitors 2>/dev/null || printf '[]')"

python3 - "$monitors_json" <<'PY'
import json
import sys

try:
    monitors = json.loads(sys.argv[1])
except Exception:
    monitors = []

focused = next((monitor for monitor in monitors if monitor.get("focused")), monitors[0] if monitors else {})
active = (focused.get("activeWorkspace") or {}).get("name", "")
special = (focused.get("specialWorkspace") or {}).get("name", "")

name = special or active
css_class = "default"

if name.startswith("special:"):
    name = name.split(":", 1)[1] or "secret"
    css_class = "special"

label = name.replace("_", " ").replace("-", " ").strip()
label = label.title() if label else "Workspace"

print(json.dumps({"text": label, "tooltip": f"Current workspace: {label}", "class": css_class}))
PY
