# Arch + Hyprland Dotfiles

Minimal but complete starter dotfiles for an Arch Linux + Hyprland setup.

## Included

- Hyprland core config (modular)
- Hyprpaper wallpaper config
- Hyprlock lock screen config
- Hypridle idle/DPMS/suspend config
- Waybar config + styles
- Rofi launcher config
- Ghostty terminal config
- Mako notifications config
- Zsh + Starship prompt config
- Small helper scripts (screenshot, power menu)

## Repo layout

```
.
├── .config
│   ├── hypr
│   ├── ghostty
│   ├── mako
│   ├── rofi
│   ├── starship.toml
│   └── waybar
├── .zshrc
├── install.sh
└── packages
    ├── aur.txt
    └── pacman.txt
```

## Quick start

1. Clone this repo:

   ```bash
   git clone <your-repo-url> ~/myrice
   cd ~/myrice
   ```

2. Install packages (official + AUR if `yay` is available):

   ```bash
   ./install.sh --install-packages
   ```

3. Symlink configs into your `$HOME`:

   ```bash
   ./install.sh
   ```

4. Put a wallpaper at:

   ```
   ~/Pictures/wallpapers/default.jpg
   ```

5. Log into Hyprland.

## Default keybinds

- `SUPER + Return`: open terminal (ghostty)
- `SUPER + Q`: close active window
- `SUPER + E`: open file manager (nemo)
- `SUPER + R`: launcher (rofi)
- `SUPER + V`: toggle floating
- `SUPER + F`: fullscreen
- `SUPER + H/J/K/L`: move focus
- `SUPER + SHIFT + H/J/K/L`: move active window
- `SUPER + 1..0`: switch workspace
- `SUPER + SHIFT + 1..0`: move window to workspace
- `SUPER + S`: area screenshot
- `SUPER + SHIFT + S`: full screenshot
- `SUPER + ESC`: power menu

## Notes

- This is a sane baseline. Tune monitor names, keyboard layout, and app choices.
- Russian keyboard layout is already enabled in `~/.config/hypr/input.conf` (`us,ru`, switch with `Alt+Shift`).
- Russian locale is exported from `~/.config/hypr/env.conf`, but on Arch you still need to generate it system-wide: enable `ru_RU.UTF-8 UTF-8` in `/etc/locale.gen`, run `sudo locale-gen`, then `sudo localectl set-locale LANG=ru_RU.UTF-8`.
- Package install now includes Russian spellchecking dictionaries (`hunspell-ru`, `aspell-ru`).
- If you use another shell/editor/file manager, update binds in `~/.config/hypr/bindings.conf`.
- Waybar now includes a GPU module (`~/.config/waybar/scripts/gpu.sh`) with NVIDIA/AMD/Intel fallback.
- For better temp readings run `sudo sensors-detect` once and reboot.
