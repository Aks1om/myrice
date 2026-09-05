# myrice

My Arch + Hyprland setup. Bar/shell migrated from Waybar to a custom
Quickshell (QML) shell. Includes a staged installer that can bring a
fresh Arch box to a portable base desktop. Machine-specific system and laptop
changes are explicit opt-ins.

## What's in the box

- **Hyprland** core config (modular: env / monitors / input / rules / bindings / autostart)
- **Quickshell** (QML) bar + panels: Wi-Fi, Bluetooth, Volume, Battery, Workspaces, Tray, Clock, AppLauncher, PowerMenu, DisplayMenu, ScaleMenu, ScreenshotMenu, MediaPlayer, Notifications
- **hyprlock / hypridle / hyprpaper**
- **swaync** for system notifications
- **ghostty** terminal
- **zsh + starship** prompt
- **Waybar** kept as an optional fallback bar
- Hypr helper scripts (screenshot, scale, system-monitor, toggle-special-window, lock-input, …)
- Manual two-state power mode: normal or battery backlight (`.config/hypr/scripts/power-mode.sh`)
- Lid-handler toggle for "mobile" mode (`home/.local/bin/lid-mobile-toggle` + `lid-mobile.service`)
- System presets in `system/etc/` (NetworkManager Wi-Fi powersave, optional rtw88 stability options, journald 500M cap, systemd-oomd slice policies, pacman→timeshift pre-transaction hook)
- Bootloader helpers: add `pcie_aspm=off` to entries, generate a mirrored `linux-lts` fallback entry
- Backup & rollback strategy with Timeshift (see [docs/BACKUP.md](docs/BACKUP.md))

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
│   │   └── lid-mobile.service
│   └── .local/bin/                # symlinked into ~/.local/bin/
│       └── lid-mobile-toggle
│   └── .local/share/applications/ # symlinked into ~/.local/share/applications/
│       └── org.telegram.desktop.desktop # Telegram portal file-picker override
├── system/                        # deployed into /etc and /boot by install.sh
│   ├── etc/
│   │   ├── modprobe.d/            #   rtw88 stability presets (no-op without the wifi fix)
│   │   └── NetworkManager/conf.d/ #   wifi.powersave=2
│   └── bootloader/
│       └── patch-pcie-aspm.sh     #   idempotent patcher for systemd-boot entries
│   └── sddm/                      #   opt-in login theme and Hyprland session artifacts
├── packages/
│   ├── pacman.txt
│   ├── lts-kernel.txt              # opt-in fallback-kernel packages
│   ├── nvidia.txt                  # explicit NVIDIA baseline only
│   └── aur.txt
├── profiles/                      # portable base plus opt-in JSON fragments
├── scripts/
│   └── generate-theme.py            # regenerate theme outputs from tokens.json
├── .zshrc
├── bootstrap.sh                   # safe profile-aware entrypoint
├── install.sh                     # staged installer (see below)
├── SETUP.md                       # longer manual setup notes
└── docs/                          # upstream docs, design refs
```

## Quick start

```bash
git clone https://github.com/Aks1om/myrice.git myrice
cd myrice
./bootstrap.sh plan
./bootstrap.sh doctor
./bootstrap.sh doctor --json
./bootstrap.sh lock
./bootstrap.sh bootstrap --dry-run
```

`bootstrap.sh` resolves `profiles/base.json`. Its base installs packages and
user dotfiles only; it never changes `/etc`, `/boot`, drivers, Wi-Fi, SDDM, or
laptop services. Review the plan before applying it, then omit `--dry-run` to
run it. `--yes` passes `--noconfirm` down to pacman/yay.

Add hardware or system work only with an explicit fragment:

```bash
./bootstrap.sh plan --profile profiles/optional/laptop-rtl8821ce.json
./bootstrap.sh bootstrap --profile profiles/optional/system-management.json --dry-run
./bootstrap.sh bootstrap --profile profiles/optional/lts-kernel.json --dry-run
./bootstrap.sh bootstrap --profile profiles/optional/nvidia.json --dry-run
```

Copy `profiles/local/example.json.example` to `profiles/local/*.json` for
machine-local choices. Those JSON files are gitignored; do not put secrets in
them.

### NVIDIA is explicit only

`profiles/optional/nvidia.json` enables `nvidia` and `nvidia-prime` only when
the `nvidia_graphics` capability is explicitly set. It installs the modern
`nvidia-open-dkms`, `nvidia-utils`, `egl-wayland`, and `nvidia-prime` baseline
from `packages/nvidia.txt`; it does not select legacy drivers, detect hardware,
or apply itself automatically. Review `./bootstrap.sh doctor` before and after
an opt-in install.

## Bootstrap environment records

`./bootstrap.sh doctor` is read-only. Its GPU section reports only PCI GPU
class/vendor data and NVIDIA/PRIME/EGL-Wayland readiness; it never prints
serials, MAC addresses, or host names. Use `--json` for automation.

`./bootstrap.sh lock` writes a non-secret reproducibility record to
`${XDG_STATE_HOME:-~/.local/state}/myrice/bootstrap-lock.json`, with the repo
commit, package-manifest hashes, selected profile names, and timestamp. It does
not require root.

Real bootstrap/install runs record planned and applied managed paths in the
same state directory. `./bootstrap.sh rollback --plan` only displays the latest
applied paths; rollback never deletes or restores anything automatically.

## Compatible staged install

```
./install.sh --help                       # show full help
./install.sh --stage preflight            # sanity checks only
./install.sh --stage dotfiles             # symlink configs into $HOME
./install.sh --all --skip system          # skip /etc deployments
./install.sh --all --dry-run              # print what would happen
./install.sh --all --laptop-wifi-fix      # include RTL8821CE driver
./install.sh --stage sddm-theme           # install MyRice's SDDM login screen
./install.sh --stage myrice-hyprland-session # install MyRice's separate SDDM session
```

The `system-management` profile installs SDDM before deploying the MyRice
Hyprland SDDM session. `install.sh` remains available for existing workflows and flags. Its `--all`
behaviour is unchanged except that RTL8821CE Wi-Fi files are now installed only
by the explicit `wifi-fix` stage. Prefer `bootstrap.sh` on a new machine.

Stages:

| Stage      | What it does |
|------------|--------------|
| `preflight`| Arch check, non-root, sudo refresh, AUR helper present |
| `pacman`   | `pacman -Syu` + everything in `packages/pacman.txt` |
| `aur`      | `yay -S` everything (uncommented) in `packages/aur.txt` |
| `dotfiles` | Symlink every `.config/*` and `home/*` into `$HOME`, then generate the theme outputs. Existing files moved to `~/.myrice_backup_<ts>/` |
| `system`   | Copy generic `system/etc/*` into `/etc/*`. RTL8821CE and Wi-Fi files remain opt-in. Overwritten files are backed up to `/var/backups/myrice-<ts>/` |
| `services` | `systemctl --user enable --now` for shipped user units |
| `locale`   | Generate `ru_RU.UTF-8` if missing |
| `lts-kernel` | Install `linux-lts` + add a mirrored systemd-boot entry. Your fallback when the main kernel breaks. |
| `backup`   | Install `timeshift`, materialise `/etc/timeshift/timeshift.json` from the template (root UUID auto-detected), deploy the pre-pacman snapshot hook, and create a first known-good snapshot. See [docs/BACKUP.md](docs/BACKUP.md) for the rollback workflow. |
| `sddm` | Install SDDM for the opt-in MyRice Hyprland session. |
| `sddm-theme` | **Opt-in.** Install the monochrome MyRice SDDM login screen and select it in SDDM. |
| `wifi-fix` | **Opt-in.** Installs `rtl8821ce-dkms-git`, deploys rtw88 blacklist, runs `patch-pcie-aspm.sh`, rebuilds initramfs. For the Realtek RTL8821CE chipset that drops the link with `"failed to get tx report from firmware"`. |
| `myrice-hyprland-session` | **Opt-in.** Installs a separate `MyRice Hyprland` SDDM session. It runs `Hyprland --config "$HOME/.config/hypr/hyprland.conf"` and leaves the packaged `Hyprland` session unchanged. |

The installer is idempotent: re-running it skips already-linked files
and already-deployed configs.

## After install

1. Put a wallpaper at `~/Pictures/wallpapers/default.jpg` (or edit `.config/hypr/hyprpaper.conf`).
2. Log into Hyprland.
3. If `--laptop-wifi-fix` was used, **reboot** so the out-of-tree `8821ce` module takes over from `rtw88_8821ce`.

## MyRice Hyprland SDDM session

Install it without running any other installer stage:

```bash
./install.sh --stage myrice-hyprland-session
```

This deploys `/usr/local/bin/myrice-hyprland` and
`/usr/local/share/wayland-sessions/myrice-hyprland.desktop`. It also installs
the narrow SDDM drop-in `/etc/sddm.conf.d/90-myrice-wayland-sessions.conf`,
which preserves `/usr/share/wayland-sessions` while adding `/usr/local/share/wayland-sessions`.
At the next SDDM login, choose **MyRice Hyprland**; do not restart the current
Hyprland or SDDM session just to activate it.

To roll back, choose the stock **Hyprland** session at SDDM, then remove only
the three MyRice-managed files:

```bash
sudo rm /usr/local/bin/myrice-hyprland \
  /usr/local/share/wayland-sessions/myrice-hyprland.desktop \
  /etc/sddm.conf.d/90-myrice-wayland-sessions.conf
```

## Theme tokens

`.config/quickshell/theme/tokens.json` is the single source of truth for the
Quickshell theme, static UI metrics, and SwayNC palette/radii. `Colors.qml`,
`Metrics.qml`, and `.config/swaync/theme.css` are generated files; do not edit
them manually. `metrics.density` is static design density for the shell
toolkit, not monitor scale; reusable components live in `.config/quickshell/ui/`
and import as `import "ui" as Ui`.

The `dotfiles` installer stage runs the generator after symlinking the configs,
so a fresh install and future `./install.sh --stage dotfiles` updates need no
manual theme step. After changing tokens during development, regenerate and
verify the committed outputs with:

```bash
python3 scripts/generate-theme.py
python3 scripts/generate-theme.py --check
```

`--check` exits non-zero when any generated file is stale.

## Notes

- Russian layout is enabled in `~/.config/hypr/input.conf` (`us,ru`, toggle `Alt+Shift`).
- Power mode is manual only: click its bar icon to switch between normal and battery. Battery sets only the single built-in backlight to 40%; normal restores the exact prior brightness. It does not change refresh rate, PPD, GPU, compositor, terminal, Wi-Fi, or idle settings.
- Monitor names in `.config/hypr/monitors.conf` are mine — tune for your hardware.
- `doctor` reports missing optional personal commands (`ollama`, `opencode`,
  `solitaire-tui`) without making them package requirements.
- Telegram's user desktop entry sets `QT_QPA_PLATFORMTHEME=xdgdesktopportal` only
  for launches through its desktop entry, so its file picker uses the portal
  without changing the global Qt environment. Restart Telegram, then launch it
  from the application launcher for the override to take effect.
- `SETUP.md` has the long-form manual walkthrough; `install.sh` automates most of it.

## Desktop actions and monitor scenes

`~/.local/bin/myrice-action` is the user-scoped CLI for common desktop actions.
It checks each required command before use and never uses `eval` or root access.

```bash
myrice-action lock
myrice-action screenshot area
myrice-action audio up
myrice-action brightness down
myrice-action power profile balanced
myrice-action doctor
myrice-action status
```

Power profiles are explicit best-effort requests through `powerprofilesctl`:
`battery`, `balanced`, `performance`, `gaming`, and `presentation`. The last two
map to `performance` and `balanced` respectively. If `powerprofilesctl` is not
available, the command reports that no profile was changed and does not require
root access.

Monitor scenes are declarative JSON files in
`~/.config/myrice/scenes/{home,office,presentation}.json`. Their example output
names are deliberately generic and must be changed to the names reported by
`hyprctl monitors` on the target computer. The scene helper does not read or
modify `.config/hypr/monitors.conf`; it validates enabled output names against
the current Hyprland session before applying any `hyprctl keyword monitor`
command.

```bash
myrice-scene --list
myrice-scene --dry-run office
myrice-scene office
myrice-scene presentation
```

`--dry-run` prints the exact commands without requiring a running Hyprland
session. A scene may request one of the power profiles above only when that
scene is explicitly invoked.

## Keybinds

See `.config/hypr/bindings.hl` for the source of truth.
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
- `SUPER + L` — lock with `myrice-action`
- `SUPER + SHIFT + P` — preview the presentation monitor scene
- `SUPER + CTRL + P` — apply the presentation monitor scene
