#!/usr/bin/env bash

set -euo pipefail

if command -v missioncenter >/dev/null 2>&1; then
  exec missioncenter
fi

if command -v gnome-system-monitor >/dev/null 2>&1; then
  exec gnome-system-monitor
fi

if command -v resources >/dev/null 2>&1; then
  exec resources
fi

if command -v btop >/dev/null 2>&1; then
  exec ghostty -e btop
fi

if command -v htop >/dev/null 2>&1; then
  exec ghostty -e htop
fi

notify-send "System monitor" "No system monitor is installed"
