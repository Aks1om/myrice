#!/usr/bin/env bash

set -euo pipefail

theme="$HOME/.config/rofi/macos.rasi"

mapfile -t entries < <(
  hyprctl -j clients | python3 -c 'import json, sys

APP_NAMES = {
    "com.mitchellh.ghostty": "Ghostty",
    "firefox": "Firefox",
    "Brave-browser": "Brave",
    "brave-browser": "Brave",
    "Chromium": "Chromium",
    "chromium": "Chromium",
    "Google-chrome": "Chrome",
    "google-chrome": "Chrome",
    "Code": "Code",
    "code": "Code",
    "code-oss": "Code OSS",
    "VSCodium": "Codium",
    "codium": "Codium",
    "discord": "Discord",
    "vesktop": "Vesktop",
    "TelegramDesktop": "Telegram",
    "org.telegram.desktop": "Telegram",
    "Spotify": "Spotify",
    "spotify": "Spotify",
    "nemo": "Files",
}

def pretty_app_name(raw):
    if not raw:
        return "App"
    if raw in APP_NAMES:
        return APP_NAMES[raw]
    cleaned = raw.split(".")[-1].replace("-", " ").replace("_", " ").strip()
    return " ".join(part.capitalize() for part in cleaned.split()) or raw

clients = json.load(sys.stdin)
rows = []

for client in clients:
    if not client.get("mapped"):
        continue

    workspace = client.get("workspace") or {}
    workspace_name = str(workspace.get("name", ""))

    if workspace_name.startswith("special:"):
        continue

    address = str(client.get("address", "")).strip()
    if not address:
        continue

    app = pretty_app_name(str(client.get("class") or client.get("initialClass") or ""))
    title = str(client.get("title") or client.get("initialTitle") or app).replace("\n", " ").strip()
    workspace_label = workspace_name or str(workspace.get("id", "")).strip()
    focus_id = client.get("focusHistoryID")

    display = f"{app}  ·  {title}"
    if workspace_label:
        display += f"  ·  {workspace_label}"

    rows.append((focus_id if isinstance(focus_id, int) else 9999, app.lower(), title.lower(), address, display))

for _, _, _, address, display in sorted(rows, key=lambda row: (row[0], row[1], row[2])):
    print(f"{address}\t{display}")'
)

if [[ ${#entries[@]} -eq 0 ]]; then
  exit 0
fi

labels=()
for entry in "${entries[@]}"; do
  labels+=("${entry#*$'\t'}")
done

choice_index="$({
  printf '%s\n' "${labels[@]}"
} | rofi -dmenu -i -format i -p 'Switch' -mesg 'Type to filter open windows' -theme "$theme" || true)"

if [[ -z "$choice_index" || ! "$choice_index" =~ ^[0-9]+$ ]]; then
  exit 0
fi

address="${entries[$choice_index]%%$'\t'*}"
hyprctl dispatch focuswindow "address:$address" >/dev/null
