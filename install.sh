#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

FILES=(
  ".zshrc"
  ".config/hypr/hyprland.conf"
  ".config/hypr/env.conf"
  ".config/hypr/monitors.conf"
  ".config/hypr/input.conf"
  ".config/hypr/rules.conf"
  ".config/hypr/bindings.conf"
  ".config/hypr/autostart.conf"
  ".config/hypr/hyprpaper.conf"
  ".config/hypr/hyprlock.conf"
  ".config/hypr/hypridle.conf"
  ".config/hypr/scripts/screenshot.sh"
  ".config/hypr/scripts/powermenu.sh"
  ".config/hypr/scripts/startmenu.sh"
  ".config/rofi/menu-mode.sh"
  ".config/waybar/config.jsonc"
  ".config/waybar/style.css"
  ".config/waybar/launch.sh"
  ".config/waybar/scripts/gpu.sh"
  ".config/ghostty/config"
  ".config/rofi/config.rasi"
  ".config/mako/config"
  ".config/starship.toml"
)

install_packages() {
  if [[ "${EUID}" -eq 0 ]]; then
    echo "Do not run as root. Use your normal user with sudo rights."
    exit 1
  fi

  mapfile -t PACMAN_PKGS < <(grep -vE '^\s*#|^\s*$' "${DOTFILES_DIR}/packages/pacman.txt")
  if [[ "${#PACMAN_PKGS[@]}" -gt 0 ]]; then
    sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"
  fi

  if command -v yay >/dev/null 2>&1; then
    mapfile -t AUR_PKGS < <(grep -vE '^\s*#|^\s*$' "${DOTFILES_DIR}/packages/aur.txt")
    if [[ "${#AUR_PKGS[@]}" -gt 0 ]]; then
      yay -S --needed --noconfirm "${AUR_PKGS[@]}"
    fi
  else
    echo "yay not found; skipping AUR packages."
  fi
}

link_one() {
  local rel="$1"
  local src="${DOTFILES_DIR}/${rel}"
  local dst="${HOME}/${rel}"

  mkdir -p "$(dirname "${dst}")"

  if [[ -e "${dst}" || -L "${dst}" ]]; then
    mkdir -p "${BACKUP_DIR}/$(dirname "${rel}")"
    mv "${dst}" "${BACKUP_DIR}/${rel}"
  fi

  ln -s "${src}" "${dst}"
}

if [[ "${1:-}" == "--install-packages" ]]; then
  install_packages
fi

if [[ ! -d "${BACKUP_DIR}" ]]; then
  mkdir -p "${BACKUP_DIR}"
fi

for file in "${FILES[@]}"; do
  if [[ -e "${DOTFILES_DIR}/${file}" ]]; then
    link_one "${file}"
  else
    echo "Warning: missing ${file}, skipping."
  fi
done

echo "Dotfiles installed."
echo "Backup (if any): ${BACKUP_DIR}"
