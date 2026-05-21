# myrice

My Arch + Hyprland setup. Bar/shell migrated from Waybar to a custom
Quickshell (QML) shell. Includes a staged installer that can bring a
fresh Arch box to my exact desktop.

## What's in the box

- **Hyprland** core config (modular: env / monitors / input / rules / bindings / autostart)
- **Quickshell** (QML) bar + panels: Wi-Fi, Bluetooth, Volume, Battery, Workspaces, Tray, Clock, AppLauncher, PowerMenu, DisplayMenu, ScaleMenu, ScreenshotMenu, MediaPlayer, Notifications
- **hyprlock / hypridle / hyprpaper**
- **swaync** for system notifications
- **ghostty** terminal
- **zsh + starship** prompt
- **Waybar** kept as an optional fallback bar
- Hypr helper scripts (screenshot, scale, system-monitor, toggle-special-window, lock-input, …)
- AC-aware power-mode switcher (`home/.local/bin/power-mode.sh` + `power-mode-watch.service`)
- Lid-handler toggle for "mobile" mode (`home/.local/bin/lid-mobile-toggle` + `lid-mobile.service`)
- System presets in `system/etc/` (NetworkManager Wi-Fi powersave, optional rtw88 stability options)
- Bootloader helper to add `pcie_aspm=off` to systemd-boot entries

## Repo layout

```
.
├── .config/                       # symlinked into ~/.config/ by install.sh
│   ├── hypr/                      #   Hyprland + scripts
│   ├── quickshell/                #   Quickshell QML shell (Bar.qml, *Panel.qml, …)
│   ├── waybar/                    #   optional fallback bar
│   ├── swaync/                    #   notification daemon
│   ├── ghostty/                   #   terminal
│   └── starship.toml
├── home/
│   ├── .config/systemd/user/      # symlinked into ~/.config/systemd/user/
│   │   ├── power-mode-watch.service
│   │   └── lid-mobile.service
│   └── .local/bin/                # symlinked into ~/.local/bin/
│       ├── power-mode.sh
│       └── lid-mobile-toggle
├── system/                        # deployed into /etc and /boot by install.sh
│   ├── etc/
│   │   ├── modprobe.d/            #   rtw88 stability presets (no-op without the wifi fix)
│   │   └── NetworkManager/conf.d/ #   wifi.powersave=2
│   └── bootloader/
│       └── patch-pcie-aspm.sh     #   idempotent patcher for systemd-boot entries
├── packages/
│   ├── pacman.txt
│   └── aur.txt
├── .zshrc
├── install.sh                     # staged installer (see below)
├── SETUP.md                       # longer manual setup notes
└── docs/                          # upstream docs, design refs
```

## Quick start

```bash
git clone https://github.com/Aks1om/myrice.git ~/GitHub/myrice
cd ~/GitHub/myrice
./install.sh --all --yes
```

`--all` runs every stage in order. `--yes` passes `--noconfirm` down to
pacman/yay. Drop `--yes` to confirm each pacman batch interactively.

## Staged install

```
./install.sh --help                       # show full help
./install.sh --stage preflight            # sanity checks only
./install.sh --stage dotfiles             # symlink configs into $HOME
./install.sh --all --skip system          # skip /etc deployments
./install.sh --all --dry-run              # print what would happen
./install.sh --all --laptop-wifi-fix      # include RTL8821CE driver
```

Stages:

| Stage      | What it does |
|------------|--------------|
| `preflight`| Arch check, non-root, sudo refresh, AUR helper present |
| `pacman`   | `pacman -Syu` + everything in `packages/pacman.txt` |
| `aur`      | `yay -S` everything (uncommented) in `packages/aur.txt` |
| `dotfiles` | Symlink every `.config/*` and `home/*` into `$HOME`. Existing files moved to `~/.myrice_backup_<ts>/` |
| `system`   | Copy `system/etc/*` into `/etc/*`. Overwritten files backed up to `/var/backups/myrice-<ts>/` |
| `services` | `systemctl --user enable --now` for shipped user units |
| `locale`   | Generate `ru_RU.UTF-8` if missing |
| `wifi-fix` | **Opt-in.** Installs `rtl8821ce-dkms-git`, deploys rtw88 blacklist, runs `patch-pcie-aspm.sh`, rebuilds initramfs. For the Realtek RTL8821CE chipset that drops the link with `"failed to get tx report from firmware"`. |

The installer is idempotent: re-running it skips already-linked files
and already-deployed configs.

## After install

1. Put a wallpaper at `~/Pictures/wallpapers/default.jpg` (or edit `.config/hypr/hyprpaper.conf`).
2. Log into Hyprland.
3. If `--laptop-wifi-fix` was used, **reboot** so the out-of-tree `8821ce` module takes over from `rtw88_8821ce`.

## Notes

- Russian layout is enabled in `~/.config/hypr/input.conf` (`us,ru`, toggle `Alt+Shift`).
- Power switcher: on AC → 120 Hz + 80 % brightness, on battery → 60 Hz + 40 %. PPD stays in `performance` in both modes (see `home/.local/bin/power-mode.sh`).
- Monitor names in `.config/hypr/monitors.conf` are mine — tune for your hardware.
- `SETUP.md` has the long-form manual walkthrough; `install.sh` automates most of it.

## Keybinds

See `.config/hypr/bindings.conf` for the source of truth.
Highlights:

- `SUPER + T` — terminal (ghostty)
- `SUPER + Space` — Quickshell AppLauncher
- `SUPER + Q` — close window
- `SUPER + F` — fullscreen
- `SUPER + V` — toggle floating
- `SUPER + H/J/K/L` — focus
- `SUPER + SHIFT + H/J/K/L` — move window
- `SUPER + 1..0` — workspace
- `SUPER + SHIFT + 1..0` — move to workspace
- `SUPER + S` — area screenshot
- `SUPER + ESC` — power menu
