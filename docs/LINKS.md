# Documentation Links — myrice stack

> Canonical documentation for every component of the active rice setup.
> Snapshot of the actual machine state, not just what's in `packages/*.txt`.
>
> **Captured:** 2026-05-18 (Arch Linux, Hyprland, Wayland)
> **Sources:** `pacman -Qqe` + `~/.config/` + active processes (`pgrep`)

For each component: short purpose · ArchWiki · upstream repo / site · man pages (where useful).

---

## Hyprland & ecosystem

### hyprland
Tiling Wayland compositor. The compositor that owns the screen.
- ArchWiki: https://wiki.archlinux.org/title/Hyprland
- Wiki (upstream): https://wiki.hypr.land/
- Repo: https://github.com/hyprwm/Hyprland
- Man: `hyprland(1)`, `hyprctl(1)`

### hyprpaper
Wallpaper daemon for Hyprland. IPC-controlled.
- Wiki: https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/
- Repo: https://github.com/hyprwm/hyprpaper

### hyprlock
Lock screen for Hyprland.
- Wiki: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
- Repo: https://github.com/hyprwm/hyprlock
- Man: `hyprlock(1)`

### hypridle
Idle daemon (DPMS / lock / suspend timers).
- Wiki: https://wiki.hypr.land/Hypr-Ecosystem/hypridle/
- Repo: https://github.com/hyprwm/hypridle

### hyprshot
Screenshot tool tightly integrated with Hyprland.
- Repo: https://github.com/Gustash/Hyprshot

### hyprpolkitagent
Qt/QML polkit authentication agent by hyprwm.
- Wiki: https://wiki.hypr.land/Hypr-Ecosystem/hyprpolkitagent/
- Repo: https://github.com/hyprwm/hyprpolkitagent

> Note: also have `polkit-gnome` installed — currently it's the one actually running in `exec-once`. `hyprpolkitagent` is the modern alternative if you want to switch off the GNOME stack.

### xdg-desktop-portal-hyprland
Portal backend for Hyprland (screen sharing, file pickers).
- Wiki: https://wiki.hypr.land/Useful-Utilities/Hyprland-desktop-portal/
- Repo: https://github.com/hyprwm/xdg-desktop-portal-hyprland

### xdg-desktop-portal-gtk
GTK fallback portal (file dialogs, settings).
- ArchWiki: https://wiki.archlinux.org/title/XDG_Desktop_Portal
- Repo: https://github.com/flatpak/xdg-desktop-portal-gtk

---

## Shell UI — bar / launcher / widgets

### quickshell-git (AUR)
QtQuick/QML toolkit for building bars, launchers, widgets, lockscreens.
**Currently the active bar + launcher + notifications on this machine** (`qs` in exec-once).
- Site: https://quickshell.org/
- Docs: https://quickshell.org/docs/
- Repo: https://github.com/quickshell-mirror/quickshell

### waybar
Highly customizable Wayland bar. Installed but not running on this machine — replaced by quickshell.
- ArchWiki: https://wiki.archlinux.org/title/Waybar
- Repo + wiki: https://github.com/Alexays/Waybar
- Man: `waybar(5)`

---

## Notifications

### swaync (SwayNotificationCenter)
Notification daemon + control center panel. **Active.**
- Repo / wiki: https://github.com/ErikReider/SwayNotificationCenter
- Man: `swaync(1)`, `swaync-client(1)`

### mako
Lightweight Wayland notification daemon. Installed but not active.
- ArchWiki: https://wiki.archlinux.org/title/Mako
- Repo: https://github.com/emersion/mako
- Man: `mako(1)`, `mako(5)`, `makoctl(1)`

---

## Terminal

### ghostty
Fast, GPU-accelerated terminal emulator. Native GTK4 on Linux.
- Site: https://ghostty.org/
- Docs: https://ghostty.org/docs
- Repo: https://github.com/ghostty-org/ghostty

---

## Login / session

### greetd
Generic greeter daemon (login manager).
- ArchWiki: https://wiki.archlinux.org/title/Greetd
- Upstream: https://sr.ht/~kennylevinsen/greetd
- Mirror: https://github.com/kennylevinsen/greetd
- Man: `greetd(1)`, `greetd(5)`

### greetd-regreet
Clean GTK4 greeter built on top of greetd. Active on this machine.
- Repo: https://github.com/rharish101/ReGreet

### cage
Minimal Wayland kiosk compositor. Useful as a container for greetd greeters.
- ArchWiki: https://wiki.archlinux.org/title/Cage
- Repo: https://github.com/cage-kiosk/cage

---

## File manager

### nemo
Cinnamon's file manager.
- ArchWiki: https://wiki.archlinux.org/title/File_manager#Nemo
- Repo: https://github.com/linuxmint/nemo

### nemo-fileroller
Archive manager integration for Nemo.
- Repo: https://github.com/linuxmint/nemo-extensions/tree/master/nemo-fileroller

### nemo-terminal
"Open terminal here" extension for Nemo.
- Repo: https://github.com/linuxmint/nemo-extensions/tree/master/nemo-terminal

---

## Audio (PipeWire stack)

### pipewire / pipewire-audio / pipewire-pulse
Modern audio + video server. Replaces PulseAudio and JACK.
- ArchWiki: https://wiki.archlinux.org/title/PipeWire
- Site: https://pipewire.org/

### wireplumber
Session and policy manager for PipeWire.
- ArchWiki: https://wiki.archlinux.org/title/WirePlumber
- Repo: https://gitlab.freedesktop.org/pipewire/wireplumber

### pavucontrol
Pulseaudio/PipeWire volume control GUI.
- ArchWiki: https://wiki.archlinux.org/title/PulseAudio#Front-ends
- Site: https://freedesktop.org/software/pulseaudio/pavucontrol/

### alsa-utils
ALSA command-line utilities (`alsamixer`, `aplay`, `amixer`).
- ArchWiki: https://wiki.archlinux.org/title/Advanced_Linux_Sound_Architecture
- Repo: https://github.com/alsa-project/alsa-utils

### playerctl
MPRIS media player control from CLI / keybinds.
- Repo: https://github.com/altdesktop/playerctl
- Man: `playerctl(1)`

---

## Clipboard / screenshots

### clipse (AUR)
TUI clipboard manager. **Active** (`clipse -listen` in exec-once).
- Repo: https://github.com/savedra1/clipse

### wl-clipboard
Command-line wrappers for the Wayland clipboard (`wl-copy`, `wl-paste`).
- ArchWiki: https://wiki.archlinux.org/title/Clipboard#Wayland
- Repo: https://github.com/bugaevc/wl-clipboard
- Man: `wl-copy(1)`, `wl-paste(1)`

### grim
Wayland screenshot tool (captures pixels).
- Repo: https://github.com/emersion/grim
- Man: `grim(1)`

### slurp
Wayland region selector (pairs with grim).
- Repo: https://github.com/emersion/slurp
- Man: `slurp(1)`

---

## Shell / prompt

### zsh
Z shell.
- ArchWiki: https://wiki.archlinux.org/title/Zsh
- Site: https://www.zsh.org/

### starship
Cross-shell prompt written in Rust.
- ArchWiki: https://wiki.archlinux.org/title/Starship
- Site: https://starship.rs/
- Repo: https://github.com/starship/starship

---

## Input remapping

### xremap (config present, binary NOT installed) ⚠️
Keymap remapper. `~/.config/xremap/config.yml` exists (translates Cyrillic shortcuts → Latin), and `~/.config/hypr/autostart.conf` has `exec-once = xremap …`, but the binary is not on PATH — that exec-once line currently fails silently.
- Repo: https://github.com/k0kubun/xremap
- AUR (one option): `xremap-wlroots-bin`

---

## System trays & agents

### network-manager-applet (`nm-applet`)
NetworkManager system tray.
- ArchWiki: https://wiki.archlinux.org/title/NetworkManager#nm-applet
- Repo: https://gitlab.gnome.org/GNOME/network-manager-applet

### networkmanager
Network connection manager.
- ArchWiki: https://wiki.archlinux.org/title/NetworkManager
- Repo: https://gitlab.freedesktop.org/NetworkManager/NetworkManager

### blueman / bluez-utils
Bluetooth manager (GUI + tray) and CLI utilities.
- ArchWiki: https://wiki.archlinux.org/title/Bluetooth
- Blueman repo: https://github.com/blueman-project/blueman
- BlueZ site: http://www.bluez.org/

### bluetooth-autoconnect (AUR)
Auto-connects paired+trusted Bluetooth devices on boot.
- Repo: https://github.com/jrouleau/bluetooth-autoconnect
- AUR: https://aur.archlinux.org/packages/bluetooth-autoconnect

### polkit-gnome
GNOME polkit authentication agent. **Active** (`/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1` in exec-once).
- ArchWiki: https://wiki.archlinux.org/title/Polkit#Authentication_agents
- Repo: https://gitlab.freedesktop.org/polkit/polkit-gnome

---

## Brightness / monitoring

### brightnessctl
Backlight + LED brightness from CLI / keybinds.
- ArchWiki: https://wiki.archlinux.org/title/Backlight#brightnessctl
- Repo: https://github.com/Hummer12007/brightnessctl

### btop
Resource monitor (TUI).
- ArchWiki: https://wiki.archlinux.org/title/Btop
- Repo: https://github.com/aristocratos/btop

### fastfetch
System info banner (neofetch successor).
- Repo: https://github.com/fastfetch-cli/fastfetch

### lm_sensors
Hardware sensors (CPU temp etc.).
- ArchWiki: https://wiki.archlinux.org/title/Lm_sensors
- Repo: https://github.com/lm-sensors/lm-sensors

---

## Boot / system

### plymouth
Graphical boot splash.
- ArchWiki: https://wiki.archlinux.org/title/Plymouth
- Repo: https://gitlab.freedesktop.org/plymouth/plymouth

---

## Theming

### adw-gtk-theme
libadwaita look ported to GTK3.
- Repo: https://github.com/lassekongo83/adw-gtk3

### catppuccin-gtk-theme-mocha (AUR)
Catppuccin GTK theme (Mocha flavor).
- Repo: https://github.com/catppuccin/gtk

### papirus-icon-theme
Modern icon theme.
- ArchWiki: https://wiki.archlinux.org/title/Icons#Papirus
- Repo: https://github.com/PapirusDevelopmentTeam/papirus-icon-theme

### bibata-cursor-theme-bin (AUR)
Bibata Modern cursor theme.
- Repo: https://github.com/ful1e5/Bibata_Cursor

### nwg-look
GTK3 settings editor for wlroots/Wayland (LXAppearance-like).
- Repo: https://github.com/nwg-piotr/nwg-look
- Man: `nwg-look(1)`

### qt5ct / qt6ct
Qt5 / Qt6 configuration tool — themes, fonts, palettes for Qt apps without KDE.
- ArchWiki: https://wiki.archlinux.org/title/Qt#Configuration_of_Qt_apps_under_environments_other_than_KDE_Plasma
- qt5ct: https://github.com/trialuser02/qt5ct
- qt6ct: https://github.com/trialuser02/qt6ct

### kvantum
SVG-based theming engine for Qt apps.
- ArchWiki: https://wiki.archlinux.org/title/Kvantum
- Repo: https://github.com/tsujan/Kvantum

### qt5-wayland / qt6-wayland
Wayland platform plugins for Qt5 / Qt6 (needed so Qt apps render natively under Wayland).
- ArchWiki: https://wiki.archlinux.org/title/Wayland#Qt
- Repos: bundled with Qt — https://www.qt.io/

### qt6-shadertools
QML/Quick shader compiler tools — required by quickshell.
- Qt docs: https://doc.qt.io/qt-6/qtshadertools-index.html

---

## Fonts

### ttf-jetbrains-mono-nerd
JetBrains Mono patched with Nerd Font icons. Primary monospace.
- Site: https://www.nerdfonts.com/
- Repo: https://github.com/ryanoasis/nerd-fonts

### ttf-dejavu
DejaVu font family — generic fallback.
- Site: https://dejavu-fonts.github.io/

### ttf-manrope (AUR)
Manrope sans-serif (UI / bar font).
- Site: https://manrope.com/
- Repo: https://github.com/sharanda/manrope

### inter-font
Inter typeface (UI sans-serif).
- Site: https://rsms.me/inter/
- Repo: https://github.com/rsms/inter

### noto-fonts (+ noto-fonts-cjk, noto-fonts-emoji)
Google's universal font coverage.
- ArchWiki: https://wiki.archlinux.org/title/Fonts#Noto
- Repo: https://github.com/notofonts/notofonts.github.io

### woff2-font-awesome
Font Awesome icon font (used by bars / launchers).
- Site: https://fontawesome.com/
- Repo: https://github.com/FortAwesome/Font-Awesome

---

## Locale / spell-check

### hunspell-ru
Russian dictionary for Hunspell.
- ArchWiki: https://wiki.archlinux.org/title/Spell_checkers#Hunspell

### aspell-ru
Russian dictionary for Aspell.
- ArchWiki: https://wiki.archlinux.org/title/Spell_checkers#Aspell

---

## Extras (installed but not strictly part of the rice)

### librepods-git (AUR)
AirPods control on Linux — battery, ANC, transparency, ear detection.
- Repo: https://github.com/kavishdevar/librepods
- AUR: https://aur.archlinux.org/packages/librepods-git

---

## Notes on drift between repo and live machine

Some packages in `packages/pacman.txt` and `packages/aur.txt` no longer reflect the live setup. Worth syncing when you have a moment:

- **`rofi-wayland`** — listed in `packages/pacman.txt` but not installed on the machine. Replaced by `quickshell` (launcher lives in `~/.config/quickshell/AppLauncher.qml`).
- **`swaync`** — active on machine, NOT in `packages/pacman.txt`. Should be added.
- **`clipse`** — active on machine (AUR), NOT in `packages/aur.txt`. Should be added.
- **`quickshell-git`** — active on machine (AUR), NOT in `packages/aur.txt`. Should be added.
- **`mako`** — installed but not running; `swaync` covers everything. Decide whether to keep or drop.
- **`hyprpolkitagent`** — installed but not running; `polkit-gnome` is the active one. Pick one and drop the other from packages.
- **`xremap`** — exec-once line exists, config exists, binary missing. Either install (`xremap-wlroots-bin` AUR or similar) or remove the exec-once line.

---

*Generated 2026-05-18 from a live machine snapshot — categorized index, not an offline copy of upstream docs.*
