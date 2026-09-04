# Rice Setup — Full Reference

> Arch Linux + Wayland. Minimal monochrome aesthetic (black/white, no colour accents).
> Last synced: 2026-09-04.

---

## Visual stack overview

```
Kernel (DRM/KMS)
  └── Hyprland          ← compositor, owns the screen
        ├── Quickshell   ← status bar, launcher, and control panels
        ├── Hyprpaper   ← wallpaper daemon (IPC-controlled)
        ├── Hyprlock    ← lock screen
        ├── Hypridle    ← idle/DPMS/suspend daemon
        ├── SwayNC      ← notification center (slide-in panel)
        ├── Ghostty     ← terminal emulator
        ├── nm-applet   ← network tray (systray)
        ├── blueman     ← bluetooth tray (systray)
        ├── clipse       ← clipboard history daemon
        └── polkit-gnome← authentication agent (GUI sudo prompts)
```

**Shell prompt:** Starship (minimal — dir, git, duration only)  
**GTK theme:** adw-gtk3-dark  
**Quickshell/AppLauncher icon theme:** Papirus-Dark (with hicolor fallback)
**Cursor:** Bibata-Modern-Classic, 24px  
**Font (UI/bar):** Manrope 700 + JetBrainsMono Nerd Font fallback  
**Font (terminal/lock):** JetBrainsMono Nerd Font  

---

## Config file map

```
~/.config/
├── hypr/
│   ├── hyprland.conf       ← main entry point, sources everything below
│   ├── monitors.conf       ← monitor layout (currently: auto/preferred/1x)
│   ├── env.conf            ← Wayland env vars, cursor, locale
│   ├── input.conf          ← keyboard (us,ru / alt+shift), touchpad
│   ├── bindings.hl         ← ALL keybinds
│   ├── rules.conf          ← window rules + workspace assignments
│   ├── autostart.conf      ← exec-once entries
│   ├── hyprpaper.conf      ← wallpaper path (~/Pictures/wallpapers/default.jpg)
│   ├── hyprlock.conf       ← lock screen (black bg, white clock, password field)
│   ├── hypridle.conf       ← lock@5min, DPMS@6min, suspend@30min
│   └── scripts/
│       ├── clipboard.sh         ← cliphist list and restore
│       ├── screenshot.sh        ← grim+slurp area or full-output screenshot
│       ├── toggle-special-window.sh ← send/recall window from special workspace
│       ├── toggle-layout.sh     ← toggle dwindle ↔ master
│       └── system-monitor.sh    ← launch btop in terminal
│
├── quickshell/                  ← bar, launcher, and control panels
│   ├── shell.qml                ← Quickshell entry point
│   ├── *Menu.qml / *Panel.qml   ← desktop control panels
│   └── theme/                   ← generated theme and shared UI
│
│
├── swaync/
│   ├── config.json         ← panel position, timeouts, widgets (title+dnd+list)
│   └── style.css           ← notification center CSS
│
│
├── ghostty/
│   └── config              ← black/white palette, JetBrainsMono 12, opacity 0.95
│
├── starship.toml           ← prompt: dir > git > duration | > char
│
└── gtk-3.0/settings.ini   ← adw-gtk3-dark, Adwaita icons, dark prefer
```

---

## Hyprland config structure

`hyprland.conf` sources everything via `source =`. The actual settings are split:

| File | Content |
|---|---|
| `env.conf` | `env =` lines: XCURSOR, locale, QT/GDK/SDL Wayland hints |
| `monitors.conf` | `monitor =` lines. Currently `,preferred,auto,1` (auto-detect) |
| `input.conf` | `input {}` + `gestures {}` blocks |
| `rules.conf` | `windowrule =` + `workspace =` assignments |
| `bindings.hl` | `bind =`, `bindel =`, `bindm =` |
| `autostart.conf` | `exec-once =` (waybar, hyprpaper, hypridle, swaync, etc.) |

**Core visual settings** (in hyprland.conf directly):
- Gaps: 6px inner / 12px outer
- Border: 2px, white active / grey inactive
- Rounding: 8px
- Blur: enabled, size 5, 2 passes
- Shadow: 16px range
- Layout: dwindle

---

## Waybar layout

```
[ ⊞  | 1 2 3 … 10 | ◆ | ws-label | window-title ]   [ mpris · clock ]   [ GPU | CPU | temp | net | BT | 🔔 | vol | lang | bat ]
  ↑         ↑          ↑       ↑
  start   workspaces  special  named label
  menu
```

- Right-click on the ⊞ button → power menu
- Battery module only shows when BAT0 exists
- GPU module: reads `/sys/class/drm`, falls back gracefully for iGPU
- `launch.sh` sets `GDK_SCALE=2` on displays >2560px wide

---

## Autostart sequence (exec-once)

1. `dbus-update-activation-environment` — propagate Wayland vars to D-Bus/systemd
2. `systemctl --user import-environment` — same for user units
3. `waybar` (via `launch.sh`)
4. `hyprpaper` — wallpaper
5. `hypridle` — idle daemon
6. `swaync` — notification center
7. `nm-applet` — network tray
8. `blueman-applet` — BT tray
9. `wl-paste --watch cliphist store` × 2 (text + image)
10. `polkit-gnome` — auth agent

---

## Workspace layout

| # | Name | Auto-assigned apps |
|---|---|---|
| 1 | web | Firefox, Brave, Chromium, Chrome |
| 2 | code | VS Code, VSCodium |
| 3 | chat | Discord, Vesktop, Telegram |
| 4 | shell | (manual) |
| 5 | media | Spotify |
| 6 | files | Nemo |
| 7 | docs | (manual) |
| 8 | tools | (manual) |
| 9 | misc | (manual) |
| 10 | extra | (manual) |
| special:magic | Secret | toggle with Super+S |

---

## Keybinds reference

> Full list is always available live: `Super + F1` or `Super + /`

### Windows
| Bind | Action |
|---|---|
| Super + T | Terminal (ghostty) |
| Super + Q | Close window |
| Super + Shift + Q | Exit Hyprland |
| Super + E | Files (Nautilus) |
| Super + Space | Launcher (Quickshell) |
| Super + Tab | Window switcher |
| Super + G | Toggle floating |
| Super + Shift + V | Float all on workspace |
| Super + F | Fullscreen |
| Super + Shift + T | Force tiled |
| Super + B | Toggle split direction |

### Workspaces
| Bind | Action |
|---|---|
| Super + 1–0 | Switch to workspace |
| Super + Shift + 1–0 | Move window to workspace |
| Super + S | Toggle special workspace |
| Super + Shift + S | Send/recall window to special |
| Super + scroll | Next/prev workspace |
| Super + LMB drag | Move window |
| Super + RMB drag | Resize window |

### Utilities
| Bind | Action |
|---|---|
| Super + V | Clipboard history |
| Super + N | Notification center |
| Super + Shift + N | Toggle Do Not Disturb |
| Super + W | Wi-Fi menu |
| Super + Shift + W | Network settings |
| Super + Esc | Power menu |
| Super + F1 / Super + / | Keybind cheat sheet |
| Print / Super + F12 | Screenshot (area menu) |
| Shift + Print / Super + Shift + F12 | Screenshot (full output) |
| Vol keys | wpctl ±5% |
| Brightness keys | brightnessctl ±5% |

### Input
- Layout: `us,ru` — toggle with `Alt+Shift`
- Caps Lock → Escape (remapped in input.conf)
- Touchpad: natural scroll, tap-to-click, clickfinger

---

## Idle / lock policy (hypridle)

| Timeout | Action |
|---|---|
| 5 min | Lock screen (hyprlock) |
| 6 min | DPMS off |
| 30 min | Suspend |

On sleep: `loginctl lock-session` fires before suspend.  
On resume: `hyprctl dispatch dpms on`.

---

## Colour palette (monochrome)

Everything is black/white/grey. No colour accents.

| Role | Value |
|---|---|
| Background | `#000000` |
| Foreground | `#ffffff` |
| Border active | `#ffffff` |
| Border inactive | `#7f7f7faa` |
| Muted/grey | `#5f5f5f` – `#a0a0a0` |
| Bar background | `rgba(0,0,0,0.9)` |
| Bar border | `rgba(255,255,255,0.18)` |
| Rofi bg | `#000000f2` |
| Rofi selected | `#ffffff1a` |
| Ghostty bg opacity | 0.95 |

---

## Key dependencies

```
hyprland hyprpaper hyprlock hypridle
quickshell
ghostty
swaync
starship
clipse wl-clipboard
network-manager-applet blueman
polkit-gnome
grim slurp          ← screenshot tools
brightnessctl        ← brightness keys
wireplumber pipewire ← audio (wpctl)
nautilus             ← file manager
waypaper             ← wallpaper picker/manager
adw-gtk-theme        ← GTK dark theme
papirus-icon-theme    ← fixed Quickshell/AppLauncher icon theme
bibata-cursor-theme  ← cursor
ttf-jetbrains-mono-nerd  ← monospace font
tesseract tesseract-data-eng tesseract-data-rus ← OCR keybinds
```

---

## Common tasks

**Change shared Quickshell/SwayNC theme tokens:**
```bash
# From the repository root, edit ~/.config/quickshell/theme/tokens.json, then regenerate:
python3 scripts/generate-theme.py
python3 scripts/generate-theme.py --check
```

`tokens.json` is the source of truth. Do not manually edit the generated
`~/.config/quickshell/theme/Colors.qml`, `Metrics.qml`, or
`~/.config/swaync/theme.css`. `metrics.density` is static design density for
the reusable `~/.config/quickshell/ui/` toolkit, not monitor scale.
`install.sh --stage dotfiles` runs this generation automatically after linking
the configs.

**Change wallpaper:**
```bash
# Edit path in ~/.config/hypr/hyprpaper.conf, then:
hyprctl hyprpaper wallpaper ",~/Pictures/wallpapers/newfile.jpg"
```

**Switch power mode:**
Click the power-mode icon in the Quickshell bar. The two modes are manual only:
normal and battery. Battery sets only the built-in backlight to 40%; normal
restores the exact brightness saved when battery mode was enabled. No AC watcher
is installed, and neither mode changes refresh rate, PPD, GPU, compositor,
Ghostty, Wi-Fi, or idle settings.

**Add a new monitor:**
```bash
hyprctl monitors   # get name
# Edit ~/.config/hypr/monitors.conf:
# monitor = DP-1, 1920x1080@60, 0x0, 1
```

**Add a keybind:**  
Edit `~/.config/hypr/bindings.hl`. The `show-keybinds.sh` script auto-parses it.

**Change bar modules:**  
Edit `~/.config/waybar/config.jsonc` → `modules-left/center/right`.  
Bar hot-reloads CSS on change (`reload_style_on_change: true`), but JSON needs `launch.sh` restart.

**Restart waybar:**
```bash
bash ~/.config/waybar/launch.sh
```

**Regenerate Russian locale (one-time, system):**
```bash
# Uncomment ru_RU.UTF-8 in /etc/locale.gen, then:
sudo locale-gen
sudo localectl set-locale LANG=ru_RU.UTF-8
```
