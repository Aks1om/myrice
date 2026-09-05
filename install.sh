#!/usr/bin/env bash
# myrice — Arch + Hyprland + Quickshell dotfiles installer
#
# Stages (run in order):
#   1. preflight       — sanity checks (Arch, non-root, sudo, AUR helper)
#   2. pacman          — install official packages from packages/pacman.txt
#   3. aur             — install AUR packages from packages/aur.txt (skips commented-out)
#   4. dotfiles        — symlink .config/* and home/* into $HOME, with timestamped backup
#                       then generate theme outputs from the linked token source
#   5. system          — copy system/etc/* into /etc/* (with .bak), reload modprobe
#   6. services        — enable systemd user units shipped in home/.config/systemd/user
#   7. locale          — generate ru_RU.UTF-8 if absent
#   8. lts-kernel      — install linux-lts and add a systemd-boot entry that
#                        mirrors the default cmdline. Survives broken upgrades.
#   9. backup          — install timeshift, materialise /etc/timeshift/timeshift.json
#                        from the template, deploy the pacman pre-transaction hook,
#                        and create a first known-good snapshot.
#  10. wifi-fix        — opt-in (--laptop-wifi-fix): install rtl8821ce-dkms-git,
#                        blacklist rtw88, patch cmdline, rebuild initramfs
#  11. sddm-theme       — opt-in: install the MyRice SDDM login theme
#  12. myrice-hyprland-session — opt-in: install the SDDM session that starts
#                        ~/.config/hypr/hyprland.conf without changing stock Hyprland
#
# Flags:
#   --all                run everything end-to-end
#   --stage NAME         run a single stage (preflight|pacman|aur|dotfiles|system|services|locale|lts-kernel|backup|wifi-fix|sddm|sddm-theme|myrice-hyprland-session|nvidia|nvidia-prime)
#   --skip NAME          skip a stage (can be repeated)
#   --dry-run            print quoted commands, don't change anything
#   --yes                non-interactive (passes --noconfirm to pacman/yay)
#   --non-interactive    pass --noconfirm only to the pacman package install
#   --laptop-wifi-fix    include the RTL8821CE-specific stage
#   -h, --help           this help
#
# Examples:
#   ./install.sh --all
#   ./install.sh --stage dotfiles
#   ./install.sh --all --laptop-wifi-fix --yes

set -euo pipefail

# ----- config -----
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
HOME_BACKUP_DIR="${HOME}/.myrice_backup_${STAMP}"
SYSTEM_BACKUP_DIR="/var/backups/myrice-${STAMP}"

DRY_RUN=0
ASSUME_YES=0
NON_INTERACTIVE=0
LAPTOP_WIFI_FIX=0
RUN_STAGES=()
SKIP_STAGES=()
STATE_PROFILES=()

ALL_STAGES=(preflight pacman aur dotfiles system services locale lts-kernel backup)
OPTIONAL_STAGES=(wifi-fix sddm sddm-theme myrice-hyprland-session nvidia nvidia-prime)

# ----- helpers -----
log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }
run()  {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '\033[1;90m  $\033[0m '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}
sudo_run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '\033[1;90m  # sudo\033[0m '
    printf '%q ' "$@"
    printf '\n'
  else
    sudo "$@"
  fi
}
stage_enabled() {
  local s="$1"
  for x in "${SKIP_STAGES[@]:-}"; do [[ "$x" == "$s" ]] && return 1; done
  if [[ ${#RUN_STAGES[@]} -gt 0 ]]; then
    for x in "${RUN_STAGES[@]}"; do [[ "$x" == "$s" ]] && return 0; done
    return 1
  fi
  return 0
}
stage_is_known() {
  local candidate="$1"
  local stage
  for stage in "${ALL_STAGES[@]}" "${OPTIONAL_STAGES[@]}"; do
    [[ "$stage" == "$candidate" ]] && return 0
  done
  return 1
}

# ----- arg parsing -----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)              RUN_STAGES=("${ALL_STAGES[@]}");;
    --stage)            shift; [[ $# -gt 0 ]] || { err "--stage requires a name"; exit 2; }; RUN_STAGES+=("$1");;
    --skip)             shift; [[ $# -gt 0 ]] || { err "--skip requires a name"; exit 2; }; SKIP_STAGES+=("$1");;
    --dry-run)          DRY_RUN=1;;
    --yes|-y)           ASSUME_YES=1;;
    --non-interactive)  NON_INTERACTIVE=1;;
    --laptop-wifi-fix)  LAPTOP_WIFI_FIX=1;;
    --state-profile)    shift; [[ $# -gt 0 ]] || { err "--state-profile requires a name"; exit 2; }; STATE_PROFILES+=("$1");;
    -h|--help)          sed -n '2,30p' "$0"; exit 0;;
    *) err "Unknown flag: $1"; exit 2;;
  esac
  shift
done

for stage in "${RUN_STAGES[@]}" "${SKIP_STAGES[@]}"; do
  stage_is_known "$stage" || { err "Unknown stage: $stage"; exit 2; }
done

if [[ ${#RUN_STAGES[@]} -eq 0 && $LAPTOP_WIFI_FIX -eq 0 ]]; then
  RUN_STAGES=(preflight)
  warn "No --all or --stage given. Running preflight only. See --help."
fi
if [[ $LAPTOP_WIFI_FIX -eq 1 ]]; then
  RUN_STAGES+=("wifi-fix")
fi

needs_preflight=0
for stage in "${RUN_STAGES[@]}"; do
  [[ "$stage" == preflight ]] || { needs_preflight=1; break; }
done
if [[ $needs_preflight -eq 1 ]]; then
  for stage in "${SKIP_STAGES[@]}"; do
    [[ "$stage" == preflight ]] && {
      err "--skip preflight cannot be used when running other stages"
      exit 2
    }
  done
  RUN_STAGES=(preflight "${RUN_STAGES[@]}")
fi

PAC_FLAGS=(--needed)
YAY_FLAGS=(--needed)
[[ $ASSUME_YES -eq 1 ]] && { PAC_FLAGS+=(--noconfirm); YAY_FLAGS+=(--noconfirm --answerclean N --answerdiff N --answeredit N); }

# =============== stages ===============

stage_preflight() {
  log "Preflight checks"
  if [[ $DRY_RUN -eq 1 ]]; then
    [[ -f /etc/arch-release ]] || warn "Not Arch Linux: showing the plan without applying it."
    printf '\033[1;90m  $\033[0m sudo -v\n'
    command -v yay >/dev/null 2>&1 || warn "yay not found — AUR stage would be skipped."
    return
  fi
  [[ -f /etc/arch-release ]] || { err "Not Arch Linux. Aborting."; exit 1; }
  [[ $EUID -ne 0 ]] || { err "Don't run as root. Use a normal user with sudo."; exit 1; }
  sudo -v
  command -v yay >/dev/null 2>&1 || warn "yay not found — AUR stage will be skipped."
  log "OK"
}

stage_pacman() {
  log "Installing pacman packages"
  mapfile -t pkgs < <(grep -vE '^\s*#|^\s*$' "$REPO_DIR/packages/pacman.txt")
  [[ ${#pkgs[@]} -gt 0 ]] || { warn "pacman.txt is empty"; return; }
  local pacman_flags=("${PAC_FLAGS[@]}")
  [[ $NON_INTERACTIVE -eq 1 ]] && pacman_flags+=(--noconfirm)
  sudo_run pacman -Syu "${pacman_flags[@]}" "${pkgs[@]}"
}

stage_sddm() {
  log "Installing SDDM"
  sudo_run pacman -S "${PAC_FLAGS[@]}" sddm
}

stage_sddm_theme() {
  local theme_dir="$REPO_DIR/system/sddm/myrice"
  local sddm_conf="$REPO_DIR/system/sddm/10-myrice-theme.conf"

  log "Deploying MyRice SDDM login theme (backup: $SYSTEM_BACKUP_DIR)"
  [[ -f "$sddm_conf" && -f "$theme_dir/metadata.desktop" && -f "$theme_dir/Main.qml" && -f "$theme_dir/theme.conf" ]] || {
    err "MyRice SDDM theme artifacts are missing from system/sddm"
    return 1
  }

  deploy_myrice_session_file "$sddm_conf" "/etc/sddm.conf.d/10-myrice-theme.conf" 0644
  deploy_myrice_session_file "$theme_dir/metadata.desktop" "/usr/share/sddm/themes/myrice/metadata.desktop" 0644
  deploy_myrice_session_file "$theme_dir/Main.qml" "/usr/share/sddm/themes/myrice/Main.qml" 0644
  deploy_myrice_session_file "$theme_dir/theme.conf" "/usr/share/sddm/themes/myrice/theme.conf" 0644
}

stage_nvidia() {
  log "Installing explicit NVIDIA baseline"
  mapfile -t pkgs < <(grep -vE '^\s*#|^\s*$' "$REPO_DIR/packages/nvidia.txt")
  [[ ${#pkgs[@]} -gt 0 ]] || { err "nvidia.txt is empty"; return 1; }
  sudo_run pacman -S "${PAC_FLAGS[@]}" "${pkgs[@]}"
}

stage_nvidia_prime() {
  log "NVIDIA PRIME package was included in the explicit NVIDIA baseline"
  warn "NVIDIA configuration is opt-in only; verify with ./bootstrap.sh doctor after reboot."
}

stage_aur() {
  log "Installing AUR packages"
  command -v yay >/dev/null 2>&1 || { warn "yay missing — skipping"; return; }
  mapfile -t pkgs < <(grep -vE '^\s*#|^\s*$' "$REPO_DIR/packages/aur.txt")
  [[ ${#pkgs[@]} -gt 0 ]] || { warn "aur.txt has no active entries"; return; }
  run yay -S "${YAY_FLAGS[@]}" "${pkgs[@]}"
}

# Symlink REPO_DIR/$rel → $HOME/$rel, backing up any pre-existing target.
link_into_home() {
  local rel="$1"
  local src="${2:-$REPO_DIR/$rel}"
  local dst="$HOME/$rel"
  [[ -e "$src" ]] || { warn "missing in repo: $rel"; return; }

  if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    return  # already correctly linked, idempotent
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    run mkdir -p "$HOME_BACKUP_DIR/$(dirname "$rel")"
    run mv "$dst" "$HOME_BACKUP_DIR/$rel"
  fi
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
}

ensure_phosphor_icons() {
  local target="$REPO_DIR/.config/quickshell/icons/phosphor"
  if [[ -d "$target/assets" ]]; then
    return
  fi
  log "Cloning Phosphor icon set (upstream, kept out of the repo)"
  run git clone --depth=1 --filter=blob:none https://github.com/phosphor-icons/core.git "$target"
}

stage_dotfiles() {
  log "Symlinking dotfiles (backup: $HOME_BACKUP_DIR)"
  ensure_phosphor_icons
  # .config/* — every top-level dir/file under .config in the repo
  while IFS= read -r -d '' p; do
    rel=".config/$(basename "$p")"
    link_into_home "$rel"
  done < <(find "$REPO_DIR/.config" -mindepth 1 -maxdepth 1 -print0)

  # home/.config/systemd/user/*.service
  if [[ -d "$REPO_DIR/home/.config/systemd/user" ]]; then
    for f in "$REPO_DIR"/home/.config/systemd/user/*.service; do
      [[ -f "$f" ]] || continue
      rel=".config/systemd/user/$(basename "$f")"
      link_into_home "$rel" "$f"
    done
  fi

  # home/.local/bin/*
  if [[ -d "$REPO_DIR/home/.local/bin" ]]; then
    for f in "$REPO_DIR"/home/.local/bin/*; do
      [[ -e "$f" ]] || continue
      rel=".local/bin/$(basename "$f")"
      link_into_home "$rel" "$f"
    done
  fi

  # home/.local/share/applications/*.desktop — per-app user launcher overrides
  if [[ -d "$REPO_DIR/home/.local/share/applications" ]]; then
    for f in "$REPO_DIR"/home/.local/share/applications/*.desktop; do
      [[ -f "$f" ]] || continue
      rel=".local/share/applications/$(basename "$f")"
      link_into_home "$rel" "$f"
    done
  fi

  # Top-level files (.zshrc etc.)
  for top in .zshrc; do
    [[ -e "$REPO_DIR/$top" ]] && link_into_home "$top"
  done

  local theme_generator="$REPO_DIR/scripts/generate-theme.py"
  [[ -f "$theme_generator" ]] || {
    err "Theme generator is missing: $theme_generator"
    return 1
  }
  log "Generating theme outputs from linked theme tokens"
  if ! run python3 "$theme_generator"; then
    err "Theme generation failed; fix the token file and rerun ./install.sh --stage dotfiles."
    return 1
  fi
}

# Copy system/etc/<path> → /etc/<path>, backup overwritten target.
deploy_system_file() {
  local rel="$1"  # path under system/
  local src="$REPO_DIR/system/$rel"
  local dst="/$rel"
  [[ -f "$src" ]] || return

  if [[ $DRY_RUN -eq 1 ]]; then
    sudo_run mkdir -p "$SYSTEM_BACKUP_DIR/$(dirname "$rel")"
    [[ -e "$dst" ]] && sudo_run cp -a "$dst" "$SYSTEM_BACKUP_DIR/$rel"
    sudo_run install -D -m 0644 "$src" "$dst"
    log "would deploy $dst"
    return
  fi
  if [[ -e "$dst" ]] && sudo cmp -s "$src" "$dst" 2>/dev/null; then
    return
  fi
  sudo_run mkdir -p "$SYSTEM_BACKUP_DIR/$(dirname "$rel")"
  if [[ -e "$dst" ]]; then
    sudo_run cp -a "$dst" "$SYSTEM_BACKUP_DIR/$rel"
  fi
  sudo_run install -D -m 0644 "$src" "$dst"
  log "deployed $dst"
}

stage_system() {
  log "Deploying system presets (backup: $SYSTEM_BACKUP_DIR)"
  while IFS= read -r -d '' f; do
    rel="${f#$REPO_DIR/system/}"
    # skip non-targets: helper scripts and templates (filled in by other stages)
    [[ "$rel" == bootloader/* || "$rel" == sddm/* ]] && continue
    [[ "$rel" == *.template ]] && continue
    # Wireless presets are specific to the author's RTL8821CE laptop. They
    # are deployed only by the opt-in wifi-fix stage.
    [[ "$rel" == etc/modprobe.d/blacklist-rtw88.conf || "$rel" == etc/modprobe.d/8821ce.conf || "$rel" == etc/modprobe.d/rtw88.conf || "$rel" == etc/modprobe.d/cfg80211.conf || "$rel" == etc/NetworkManager/conf.d/30-wifi-powersave.conf ]] && continue
    deploy_system_file "$rel"
  done < <(find "$REPO_DIR/system" -type f -print0)
}

stage_lts_kernel() {
  log "Setting up linux-lts as fallback kernel"
  mapfile -t pkgs < <(grep -vE '^\s*#|^\s*$' "$REPO_DIR/packages/lts-kernel.txt")
  [[ ${#pkgs[@]} -gt 0 ]] || { err "lts-kernel.txt is empty"; return 1; }
  sudo_run pacman -S "${PAC_FLAGS[@]}" "${pkgs[@]}"
  run bash "$REPO_DIR/system/bootloader/add-lts-entry.sh"
}

stage_backup() {
  log "Configuring Timeshift + pacman pre-transaction hook"
  if ! command -v timeshift >/dev/null 2>&1; then
    sudo_run pacman -S "${PAC_FLAGS[@]}" timeshift
  fi

  local tpl="$REPO_DIR/system/etc/timeshift/timeshift.json.template"
  local dst="/etc/timeshift/timeshift.json"
  if [[ ! -e "$dst" ]]; then
    local root_uuid
    root_uuid="$(findmnt -no UUID /)"
    [[ -n "$root_uuid" ]] || { err "Couldn't detect root UUID"; return 1; }
    log "Writing $dst (root UUID: $root_uuid)"
    if [[ $DRY_RUN -eq 1 ]]; then
      printf '\033[1;90m  # sudo install rendered Timeshift config at %s\033[0m\n' "$dst"
    else
      local rendered
      rendered="$(mktemp)"
      sed "s/__ROOT_UUID__/$root_uuid/" "$tpl" > "$rendered"
      sudo_run install -D -m 0644 "$rendered" "$dst"
      rm -f "$rendered"
    fi
  else
    log "$dst already exists — leaving it alone"
  fi

  # The pacman hook is deployed by stage_system already; bail if missing.
  if [[ ! -f /etc/pacman.d/hooks/50-timeshift.hook ]]; then
    deploy_system_file "etc/pacman.d/hooks/50-timeshift.hook"
  fi

  if [[ $DRY_RUN -eq 0 ]] && ! sudo timeshift --list 2>/dev/null | grep -q '_'; then
    log "Creating first known-good snapshot (this can take a few minutes)"
    sudo_run timeshift --create --comments "first known-good (myrice install)" --tags M
  fi
}

stage_services() {
  log "Enabling systemd --user services"
  run systemctl --user daemon-reload
  for f in "$REPO_DIR"/home/.config/systemd/user/*.service; do
    [[ -f "$f" ]] || continue
    local name; name="$(basename "$f")"
    if ! run systemctl --user enable --now "$name"; then
      warn "Could not enable user service: $name"
    fi
  done
}

stage_locale() {
  log "Ensuring ru_RU.UTF-8 is generated"
  if ! locale -a 2>/dev/null | grep -qi '^ru_RU\.utf'; then
    sudo_run sed -i 's/^#\s*\(ru_RU\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    sudo_run locale-gen
  fi
}

stage_wifi_fix() {
  log "Applying RTL8821CE Wi-Fi fix (opt-in)"
  command -v yay >/dev/null 2>&1 || { err "yay required for AUR install"; return 1; }

  # 1. Install DKMS driver — uncommenting it in aur.txt would also work,
  #    but we install it explicitly here so a plain --all stays generic.
  run yay -S "${YAY_FLAGS[@]}" rtl8821ce-dkms-git

  # 2. Deploy the RTL8821CE blacklist and options in this opt-in stage.
  if ! grep -q '^blacklist rtw88_8821ce' /etc/modprobe.d/blacklist-rtw88.conf 2>/dev/null; then
    deploy_system_file "etc/modprobe.d/blacklist-rtw88.conf"
    deploy_system_file "etc/modprobe.d/rtw88.conf"
  fi

  # Deploy every laptop-specific wireless preset only in this opt-in stage.
  deploy_system_file "etc/NetworkManager/conf.d/30-wifi-powersave.conf"
  deploy_system_file "etc/modprobe.d/cfg80211.conf"
  # 2b. Disable the out-of-tree 8821ce driver's internal power-save.
  #     rtw_power_mgnt=2 (default) caused reason=3 locally_generated
  #     disconnects during ACTIVE use — the radio enters LPS/IPS, loses sync,
  #     and the driver locally deauths (beacon loss = 0, so not a weak signal).
  #     8821ce.conf sets rtw_power_mgnt=0 + rtw_ips_mode=0.
  deploy_system_file "etc/modprobe.d/8821ce.conf"

  # 3. Add pcie_aspm=off to systemd-boot entries
  run bash "$REPO_DIR/system/bootloader/patch-pcie-aspm.sh"

  # 4. Rebuild initramfs so the new module is in the image
  sudo_run mkinitcpio -P

  warn "Reboot required for the new driver to take effect."
}

stage_myrice_hyprland_session() {
  local launcher="$REPO_DIR/system/sddm/myrice-hyprland"
  local desktop="$REPO_DIR/system/sddm/myrice-hyprland.desktop"
  local sddm_conf="$REPO_DIR/system/sddm/90-myrice-wayland-sessions.conf"

  log "Deploying MyRice Hyprland SDDM session (backup: $SYSTEM_BACKUP_DIR)"
  [[ -f "$launcher" && -f "$desktop" && -f "$sddm_conf" ]] || {
    err "MyRice Hyprland session artifacts are missing from system/sddm"
    return 1
  }

  deploy_myrice_session_file "$launcher" "/usr/local/bin/myrice-hyprland" 0755
  deploy_myrice_session_file "$desktop" "/usr/local/share/wayland-sessions/myrice-hyprland.desktop" 0644
  deploy_myrice_session_file "$sddm_conf" "/etc/sddm.conf.d/90-myrice-wayland-sessions.conf" 0644
}

deploy_myrice_session_file() {
  local src="$1"
  local dst="$2"
  local mode="$3"
  local backup_rel="${dst#/}"

  if [[ $DRY_RUN -eq 1 ]]; then
    sudo_run mkdir -p "$SYSTEM_BACKUP_DIR/$(dirname "$backup_rel")"
    [[ -e "$dst" ]] && sudo_run cp -a "$dst" "$SYSTEM_BACKUP_DIR/$backup_rel"
    sudo_run install -D -m "$mode" "$src" "$dst"
    log "would deploy $dst"
    return
  fi
  if [[ -e "$dst" ]] && sudo cmp -s "$src" "$dst" 2>/dev/null; then
    return
  fi
  sudo_run mkdir -p "$SYSTEM_BACKUP_DIR/$(dirname "$backup_rel")"
  if [[ -e "$dst" ]]; then
    sudo_run cp -a "$dst" "$SYSTEM_BACKUP_DIR/$backup_rel"
  fi
  sudo_run install -D -m "$mode" "$src" "$dst"
  log "deployed $dst"
}

# =============== run ===============
log "myrice installer — repo: $REPO_DIR"
[[ $DRY_RUN -eq 1 ]] && warn "DRY-RUN mode: no changes will be made"

for stage in "${ALL_STAGES[@]}" "${OPTIONAL_STAGES[@]}"; do
  stage_enabled "$stage" || continue
  case "$stage" in
    preflight)  stage_preflight;;
    pacman)     stage_pacman;;
    aur)        stage_aur;;
    dotfiles)   stage_dotfiles;;
    system)     stage_system;;
    services)   stage_services;;
    locale)     stage_locale;;
    lts-kernel) stage_lts_kernel;;
    backup)     stage_backup;;
    wifi-fix)   stage_wifi_fix;;
    sddm)       stage_sddm;;
    sddm-theme) stage_sddm_theme;;
    myrice-hyprland-session) stage_myrice_hyprland_session;;
    nvidia)     stage_nvidia;;
    nvidia-prime) stage_nvidia_prime;;
  esac
done

if [[ $DRY_RUN -eq 0 ]]; then
  state_args=(state --status applied)
  for stage in "${RUN_STAGES[@]}"; do state_args+=(--stage "$stage"); done
  if [[ ${#STATE_PROFILES[@]} -eq 0 ]]; then STATE_PROFILES=(direct-install); fi
  for profile in "${STATE_PROFILES[@]}"; do state_args+=(--profile "$profile"); done
  python3 "$REPO_DIR/scripts/environment.py" "${state_args[@]}" >/dev/null
fi

log "Done."
[[ -d "$HOME_BACKUP_DIR" ]] && log "Home backup: $HOME_BACKUP_DIR"
exit 0
