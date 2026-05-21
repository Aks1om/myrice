#!/usr/bin/env bash
# myrice — Arch + Hyprland + Quickshell dotfiles installer
#
# Stages (run in order):
#   1. preflight       — sanity checks (Arch, non-root, sudo, AUR helper)
#   2. pacman          — install official packages from packages/pacman.txt
#   3. aur             — install AUR packages from packages/aur.txt (skips commented-out)
#   4. dotfiles        — symlink .config/* and home/* into $HOME, with timestamped backup
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
#
# Flags:
#   --all                run everything end-to-end
#   --stage NAME         run a single stage (preflight|pacman|aur|dotfiles|system|services|locale|lts-kernel|backup|wifi-fix)
#   --skip NAME          skip a stage (can be repeated)
#   --dry-run            print what would happen, don't change anything
#   --yes                non-interactive (passes --noconfirm to pacman/yay)
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
LAPTOP_WIFI_FIX=0
RUN_STAGES=()
SKIP_STAGES=()

ALL_STAGES=(preflight pacman aur dotfiles system services locale lts-kernel backup)

# ----- helpers -----
log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }
run()  {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '\033[1;90m  $\033[0m %s\n' "$*"
  else
    eval "$@"
  fi
}
sudo_run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '\033[1;90m  # %s\033[0m\n' "$*"
  else
    sudo bash -c "$*"
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

# ----- arg parsing -----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)              RUN_STAGES=("${ALL_STAGES[@]}");;
    --stage)            shift; RUN_STAGES+=("$1");;
    --skip)             shift; SKIP_STAGES+=("$1");;
    --dry-run)          DRY_RUN=1;;
    --yes|-y)           ASSUME_YES=1;;
    --laptop-wifi-fix)  LAPTOP_WIFI_FIX=1;;
    -h|--help)          sed -n '2,30p' "$0"; exit 0;;
    *) err "Unknown flag: $1"; exit 2;;
  esac
  shift
done

if [[ ${#RUN_STAGES[@]} -eq 0 && $LAPTOP_WIFI_FIX -eq 0 ]]; then
  RUN_STAGES=(preflight)
  warn "No --all or --stage given. Running preflight only. See --help."
fi
if [[ $LAPTOP_WIFI_FIX -eq 1 ]]; then
  RUN_STAGES+=("wifi-fix")
fi

PAC_FLAGS="--needed"
YAY_FLAGS="--needed"
[[ $ASSUME_YES -eq 1 ]] && { PAC_FLAGS+=" --noconfirm"; YAY_FLAGS+=" --noconfirm --answerclean N --answerdiff N --answeredit N"; }

# =============== stages ===============

stage_preflight() {
  log "Preflight checks"
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
  sudo_run "pacman -Syu $PAC_FLAGS ${pkgs[*]}"
}

stage_aur() {
  log "Installing AUR packages"
  command -v yay >/dev/null 2>&1 || { warn "yay missing — skipping"; return; }
  mapfile -t pkgs < <(grep -vE '^\s*#|^\s*$' "$REPO_DIR/packages/aur.txt")
  [[ ${#pkgs[@]} -gt 0 ]] || { warn "aur.txt has no active entries"; return; }
  run "yay -S $YAY_FLAGS ${pkgs[*]}"
}

# Symlink REPO_DIR/$rel → $HOME/$rel, backing up any pre-existing target.
link_into_home() {
  local rel="$1"
  local src="$REPO_DIR/$rel"
  local dst="$HOME/$rel"
  [[ -e "$src" ]] || { warn "missing in repo: $rel"; return; }

  if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    return  # already correctly linked, idempotent
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    run "mkdir -p '$HOME_BACKUP_DIR/$(dirname "$rel")'"
    run "mv '$dst' '$HOME_BACKUP_DIR/$rel'"
  fi
  run "mkdir -p '$(dirname "$dst")'"
  run "ln -s '$src' '$dst'"
}

ensure_phosphor_icons() {
  local target="$REPO_DIR/.config/quickshell/icons/phosphor"
  if [[ -d "$target/assets" ]]; then
    return
  fi
  log "Cloning Phosphor icon set (upstream, kept out of the repo)"
  run "git clone --depth=1 --filter=blob:none https://github.com/phosphor-icons/core.git '$target'"
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
      link_into_home "$rel"
    done
  fi

  # home/.local/bin/*
  if [[ -d "$REPO_DIR/home/.local/bin" ]]; then
    for f in "$REPO_DIR"/home/.local/bin/*; do
      [[ -e "$f" ]] || continue
      rel=".local/bin/$(basename "$f")"
      link_into_home "$rel"
    done
  fi

  # Top-level files (.zshrc etc.)
  for top in .zshrc; do
    [[ -e "$REPO_DIR/$top" ]] && link_into_home "$top"
  done
}

# Copy system/etc/<path> → /etc/<path>, backup overwritten target.
deploy_system_file() {
  local rel="$1"  # path under system/
  local src="$REPO_DIR/system/$rel"
  local dst="/$rel"
  [[ -f "$src" ]] || return

  if [[ -e "$dst" ]] && sudo cmp -s "$src" "$dst" 2>/dev/null; then
    return
  fi
  sudo_run "mkdir -p '$SYSTEM_BACKUP_DIR/$(dirname "$rel")'"
  if [[ -e "$dst" ]]; then
    sudo_run "cp -a '$dst' '$SYSTEM_BACKUP_DIR/$rel'"
  fi
  sudo_run "install -D -m 0644 '$src' '$dst'"
  log "deployed $dst"
}

stage_system() {
  log "Deploying system presets (backup: $SYSTEM_BACKUP_DIR)"
  while IFS= read -r -d '' f; do
    rel="${f#$REPO_DIR/system/}"
    # skip non-targets: helper scripts and templates (filled in by other stages)
    [[ "$rel" == bootloader/* ]] && continue
    [[ "$rel" == *.template ]] && continue
    deploy_system_file "$rel"
  done < <(find "$REPO_DIR/system" -type f -print0)
}

stage_lts_kernel() {
  log "Setting up linux-lts as fallback kernel"
  if ! pacman -Q linux-lts >/dev/null 2>&1; then
    sudo_run "pacman -S $PAC_FLAGS linux-lts linux-lts-headers"
  fi
  run "bash '$REPO_DIR/system/bootloader/add-lts-entry.sh'"
}

stage_backup() {
  log "Configuring Timeshift + pacman pre-transaction hook"
  if ! command -v timeshift >/dev/null 2>&1; then
    sudo_run "pacman -S $PAC_FLAGS timeshift"
  fi

  local tpl="$REPO_DIR/system/etc/timeshift/timeshift.json.template"
  local dst="/etc/timeshift/timeshift.json"
  if [[ ! -e "$dst" ]]; then
    local root_uuid
    root_uuid="$(findmnt -no UUID /)"
    [[ -n "$root_uuid" ]] || { err "Couldn't detect root UUID"; return 1; }
    log "Writing $dst (root UUID: $root_uuid)"
    sudo_run "mkdir -p /etc/timeshift"
    sudo_run "sed 's/__ROOT_UUID__/$root_uuid/' '$tpl' > '$dst'"
  else
    log "$dst already exists — leaving it alone"
  fi

  # The pacman hook is deployed by stage_system already; bail if missing.
  if [[ ! -f /etc/pacman.d/hooks/50-timeshift.hook ]]; then
    deploy_system_file "etc/pacman.d/hooks/50-timeshift.hook"
  fi

  if [[ $DRY_RUN -eq 0 ]] && ! sudo timeshift --list 2>/dev/null | grep -q '_'; then
    log "Creating first known-good snapshot (this can take a few minutes)"
    sudo_run "timeshift --create --comments 'first known-good (myrice install)' --tags M"
  fi
}

stage_services() {
  log "Enabling systemd --user services"
  systemctl --user daemon-reload
  for f in "$REPO_DIR"/home/.config/systemd/user/*.service; do
    [[ -f "$f" ]] || continue
    local name; name="$(basename "$f")"
    run "systemctl --user enable --now '$name' || true"
  done
}

stage_locale() {
  log "Ensuring ru_RU.UTF-8 is generated"
  if ! locale -a 2>/dev/null | grep -qi '^ru_RU\.utf'; then
    sudo_run "sed -i 's/^#\s*\(ru_RU\.UTF-8 UTF-8\)/\1/' /etc/locale.gen"
    sudo_run "locale-gen"
  fi
}

stage_wifi_fix() {
  log "Applying RTL8821CE Wi-Fi fix (opt-in)"
  command -v yay >/dev/null 2>&1 || { err "yay required for AUR install"; return 1; }

  # 1. Install DKMS driver — uncommenting it in aur.txt would also work,
  #    but we install it explicitly here so a plain --all stays generic.
  run "yay -S $YAY_FLAGS rtl8821ce-dkms-git"

  # 2. modprobe blacklist + options are deployed by stage_system already
  #    (system/etc/modprobe.d/{blacklist-rtw88,rtw88}.conf).
  #    Run that stage if it was skipped:
  if ! grep -q '^blacklist rtw88_8821ce' /etc/modprobe.d/blacklist-rtw88.conf 2>/dev/null; then
    deploy_system_file "etc/modprobe.d/blacklist-rtw88.conf"
    deploy_system_file "etc/modprobe.d/rtw88.conf"
  fi

  # 3. Add pcie_aspm=off to systemd-boot entries
  run "bash '$REPO_DIR/system/bootloader/patch-pcie-aspm.sh'"

  # 4. Rebuild initramfs so the new module is in the image
  sudo_run "mkinitcpio -P"

  warn "Reboot required for the new driver to take effect."
}

# =============== run ===============
log "myrice installer — repo: $REPO_DIR"
[[ $DRY_RUN -eq 1 ]] && warn "DRY-RUN mode: no changes will be made"

for stage in "${ALL_STAGES[@]}" "wifi-fix"; do
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
  esac
done

log "Done."
[[ -d "$HOME_BACKUP_DIR" ]] && log "Home backup: $HOME_BACKUP_DIR"
