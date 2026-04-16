#!/usr/bin/env bash

set -euo pipefail

theme="$HOME/.config/rofi/macos.rasi"
bindings="$HOME/.config/hypr/bindings.conf"

python3 - "$bindings" <<'PY' | rofi -dmenu -i -p 'Shortcuts' -mesg 'Type to filter your Hyprland shortcuts' -theme "$theme" || true
import re
import sys
from pathlib import Path

WORKSPACE_NAMES = {
    "1": "Web",
    "2": "Code",
    "3": "Chat",
    "4": "Shell",
    "5": "Media",
    "6": "Files",
    "7": "Docs",
    "8": "Tools",
    "9": "Misc",
    "10": "Extra",
}

KEY_NAMES = {
    "SPACE": "Space",
    "ESCAPE": "Esc",
    "PRINT": "Print",
    "TAB": "Tab",
    "slash": "/",
    "mouse_down": "Wheel Down",
    "mouse_up": "Wheel Up",
    "mouse:272": "Drag LMB",
    "mouse:273": "Drag RMB",
    "XF86AudioRaiseVolume": "Volume Up",
    "XF86AudioLowerVolume": "Volume Down",
    "XF86AudioMute": "Mute",
    "XF86MonBrightnessUp": "Brightness Up",
    "XF86MonBrightnessDown": "Brightness Down",
}

MOD_NAMES = {
    "SUPER": "Super",
    "SHIFT": "Shift",
    "ALT": "Alt",
    "CTRL": "Ctrl",
    "CONTROL": "Ctrl",
}

variables = {}

def resolve(value):
    value = value.strip()
    seen = set()
    while value.startswith("$") and value in variables and value not in seen:
        seen.add(value)
        value = variables[value].strip()
    return value

def pretty_key(key):
    key = key.strip()
    if key in KEY_NAMES:
        return KEY_NAMES[key]
    if len(key) == 1:
        return key.upper()
    return key.title()

def workspace_label(value):
    value = value.strip()
    if value in WORKSPACE_NAMES:
        return f"{value} ({WORKSPACE_NAMES[value]})"
    return value

def describe_exec(command):
    if "window-switcher.sh" in command:
        return "Window switcher"
    if "show-keybinds.sh" in command:
        return "Show shortcut cheat sheet"
    if "startmenu.sh" in command:
        return "Open launcher"
    if "clipboard.sh" in command:
        return "Clipboard history"
    if "toggle-special-window.sh" in command:
        return "Send or return current window to Secret"
    if "screenshot.sh menu" in command:
        return "Open screenshot menu"
    if "screenshot.sh output" in command:
        return "Take full-screen screenshot"
    if "wifi-menu.sh" in command:
        return "Open Wi-Fi menu"
    if "nm-connection-editor" in command:
        return "Open network settings"
    if "powermenu.sh" in command:
        return "Open power menu"
    if command == "ghostty":
        return "Open terminal"
    if command == "nemo":
        return "Open files"
    if "swaync-client -t" in command:
        return "Open notification center"
    if "swaync-client -d" in command:
        return "Toggle Do Not Disturb"
    if command == "pavucontrol":
        return "Open sound settings"
    if command == "blueman-manager":
        return "Open Bluetooth settings"
    return "Run command"

def describe(bind_type, dispatcher, params):
    params = resolve(params)
    if dispatcher == "exec":
        return describe_exec(params)
    if dispatcher == "killactive":
        return "Close active window"
    if dispatcher == "exit":
        return "Exit Hyprland"
    if dispatcher == "togglefloating":
        return "Toggle floating"
    if dispatcher == "fullscreen":
        return "Toggle fullscreen"
    if dispatcher == "workspaceopt" and params == "allfloat":
        return "Toggle floating for all windows on workspace"
    if dispatcher == "togglespecialworkspace":
        return "Toggle Secret workspace"
    if dispatcher == "togglesplit":
        return "Toggle split direction"
    if dispatcher == "settiled":
        return "Return window to tiled mode"
    if dispatcher == "workspace":
        if params == "e+1":
            return "Next workspace"
        if params == "e-1":
            return "Previous workspace"
        return f"Go to workspace {workspace_label(params)}"
    if dispatcher == "movetoworkspace":
        return f"Move window to workspace {workspace_label(params)}"
    if dispatcher == "movewindow":
        return "Move window with mouse"
    if dispatcher == "resizewindow":
        return "Resize window with mouse"
    return "Action"

def format_combo(bind_type, mods_field, key):
    mods = []
    for token in mods_field.split():
        token = resolve(token)
        token = MOD_NAMES.get(token, token.title())
        if token:
            mods.append(token)

    key_label = pretty_key(key)
    parts = mods + ([key_label] if key_label else [])
    return " + ".join(parts) if parts else key_label

lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
rows = []

for line in lines:
    raw = line.split("#", 1)[0].strip()
    if not raw:
        continue

    if raw.startswith("$") and "=" in raw:
        name, value = raw.split("=", 1)
        variables[name.strip()] = value.strip()
        continue

    match = re.match(r"^(bindm|bindel|bind)\s*=\s*(.*)$", raw)
    if not match:
        continue

    bind_type = match.group(1)
    parts = [part.strip() for part in match.group(2).split(",")]
    if len(parts) < 3:
        continue

    mods_field, key, dispatcher = parts[:3]
    params = ",".join(parts[3:]).strip()
    combo = format_combo(bind_type, mods_field, key)
    description = describe(bind_type, dispatcher, params)
    rows.append(f"{combo}  ·  {description}")

for row in rows:
    print(row)
PY
