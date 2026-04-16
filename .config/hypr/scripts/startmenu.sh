#!/usr/bin/env bash
# Launch rofi in combi mode: menu items + app search together.
# Typing searches across both quick actions and installed apps.
set -euo pipefail

exec rofi -show combi \
          -combi-modes "script:~/.config/rofi/menu-mode.sh,drun" \
          -show-icons \
          -theme ~/.config/rofi/macos.rasi
