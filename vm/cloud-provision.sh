#!/usr/bin/env bash
# Disposable cloud-image provisioner. It deliberately does not use the ISO/QMP harness.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cloud_root="$(realpath -m -- "$repo_dir/vm/.state/cloud")"
state_dir="$(realpath -m -- "${MYRICE_CLOUD_VM_DIR:-$cloud_root}")"
image=""; port="${MYRICE_CLOUD_VM_HTTP_PORT:-18081}"; timeout_seconds="${MYRICE_VM_TIMEOUT:-900}"
install_timeout_seconds="${MYRICE_VM_INSTALL_TIMEOUT:-7200}"
disk_size="${MYRICE_CLOUD_VM_DISK_SIZE:-12G}"
dry_run=0; acceptance_only=0; resume_install=0; reset=0; yes=0
http_pid=""; qemu_pid=""; staging_dir=""

usage() {
  cat <<'EOF'
Usage: vm/cloud-provision.sh --image PATH [--acceptance-only|--resume-install] [--dry-run]
       vm/cloud-provision.sh --image PATH --reset --yes

Creates an isolated disposable cloud-image overlay in vm/.state/cloud. The
source image is never modified. --reset deletes only this provisioner's marked
cloud state.

--resume-install boots an existing marked cloud overlay without NoCloud or
source staging. It always replaces the guest checkout with a sanitized archive
of the current host worktree over SCP, then runs the real base bootstrap.
EOF
}
die() { printf 'cloud-provision: %s\n' "$*" >&2; exit 1; }
log() { printf 'cloud-provision: %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) [[ $# -ge 2 && -n "${2:-}" ]] || die '--image requires a path'; image="$2"; shift ;;
    --dry-run) dry_run=1 ;;
    --acceptance-only) acceptance_only=1 ;;
    --resume-install) resume_install=1 ;;
    --reset) reset=1 ;;
    --yes) yes=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -n "$image" ]] || die '--image PATH is required'
[[ "$port" =~ ^[0-9]{1,5}$ ]] && (( port > 0 && port < 65536 )) || die "invalid HTTP port: $port"
[[ "$timeout_seconds" =~ ^[0-9]+$ ]] && (( 10#$timeout_seconds > 0 )) || die "invalid MYRICE_VM_TIMEOUT: $timeout_seconds"
[[ "$install_timeout_seconds" =~ ^[0-9]+$ ]] && (( 10#$install_timeout_seconds > 0 )) || die "invalid MYRICE_VM_INSTALL_TIMEOUT: $install_timeout_seconds"
[[ "$disk_size" =~ ^[1-9][0-9]*[GM]$ ]] || die "invalid MYRICE_CLOUD_VM_DISK_SIZE (expected positive integer with G or M suffix): $disk_size"
[[ "$state_dir" == "$cloud_root" || "$state_dir" == "$cloud_root/"* ]] || die "unsafe cloud state path (must be below $cloud_root): $state_dir"
(( acceptance_only + resume_install + reset <= 1 )) || die '--acceptance-only, --resume-install, and --reset are mutually exclusive'

if [[ $reset -eq 1 ]]; then
  [[ $yes -eq 1 ]] || die '--reset is destructive; rerun with --reset --yes'
  [[ $dry_run -eq 0 ]] || { log "would delete marked cloud state: $state_dir"; exit 0; }
  [[ -f "$state_dir/.myrice-cloud-state" ]] || die "refusing to delete unmarked cloud state: $state_dir"
  rm -rf -- "$state_dir"
  log "deleted marked cloud state: $state_dir"
  exit 0
fi
[[ $yes -eq 0 ]] || die '--yes is valid only with --reset'

if [[ $dry_run -eq 1 ]]; then
  log "would use marked cloud state: $state_dir"
  if [[ $acceptance_only -eq 1 ]]; then
    log 'would connect with the transient cloud-state key to 127.0.0.1:2223 and run guest acceptance'
  elif [[ $resume_install -eq 1 ]]; then
    log 'would boot the existing marked cloud overlay headlessly on 127.0.0.1:2223 without NoCloud or source staging'
    log 'would archive the sanitized current worktree, SCP it to /tmp, validate it, and replace /home/arch/myrice via /home/arch/myrice.next'
    log "would wait up to ${timeout_seconds}s for guest pacman/cloud-init readiness before real bootstrap"
    log "would run /home/arch/myrice/bootstrap.sh bootstrap --non-interactive as arch from /home/arch/myrice with MYRICE_VM_INSTALL_TIMEOUT=$install_timeout_seconds"
    log "would fetch real-install.log and verification evidence to $state_dir/evidence-real-install"
  else
    log "would create a qcow2 overlay from $image, copy OVMF variables, stage NoCloud data and a sanitized current-worktree archive"
    log "would resize the new disposable overlay to $disk_size before its first cloud boot"
    log "would serve staging only on 127.0.0.1:$port and boot Q35/KVM QEMU headlessly with NoCloud SMBIOS"
  fi
  if [[ $resume_install -eq 0 ]]; then
    log "would fetch guest evidence to $state_dir/evidence and verify plan.log, doctor.log, and bootstrap-dry-run.log"
  fi
  exit 0
fi

for tool in qemu-system-x86_64 qemu-img ssh scp ssh-keygen python3 tar curl; do
  command -v "$tool" >/dev/null 2>&1 || die "required command not found: $tool"
done
[[ -r /dev/kvm && -w /dev/kvm ]] || die '/dev/kvm is not accessible'
ovmf_code=/usr/share/edk2/x64/OVMF_CODE.4m.fd
ovmf_vars=/usr/share/edk2/x64/OVMF_VARS.4m.fd
[[ -r "$ovmf_code" && -r "$ovmf_vars" ]] || die 'required OVMF_CODE.4m.fd/OVMF_VARS.4m.fd files are not readable'

cleanup() {
  local status=$? attempt
  if [[ -n "$http_pid" ]] && kill -0 "$http_pid" 2>/dev/null; then kill "$http_pid" 2>/dev/null || true; fi
  if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then kill "$qemu_pid" 2>/dev/null || true; fi
  for attempt in 1 2 3 4 5; do
    [[ -z "$http_pid" ]] || ! kill -0 "$http_pid" 2>/dev/null || sleep 1
    [[ -z "$qemu_pid" ]] || ! kill -0 "$qemu_pid" 2>/dev/null || sleep 1
  done
  if [[ -n "$http_pid" ]] && kill -0 "$http_pid" 2>/dev/null; then kill -KILL "$http_pid" 2>/dev/null || true; fi
  if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then kill -KILL "$qemu_pid" 2>/dev/null || true; fi
  [[ -z "$http_pid" ]] || wait "$http_pid" 2>/dev/null || true
  [[ -z "$qemu_pid" ]] || wait "$qemu_pid" 2>/dev/null || true
  [[ -z "$staging_dir" ]] || rm -rf -- "$staging_dir"
  exit "$status"
}
trap cleanup EXIT INT TERM

wait_for() {
  local description="$1" attempts=0; shift
  local deadline=$((SECONDS + timeout_seconds))
  until "$@" >/dev/null 2>&1; do
    (( SECONDS < deadline )) || die "timed out waiting for $description after ${timeout_seconds}s"
    attempts=$((attempts + 1))
    if (( attempts % 15 == 0 )); then
      log "still waiting for $description (${SECONDS}s elapsed)"
    fi
    sleep 2
  done
}

create_source_archive() {
  local archive_path="$1"
  tar --create --gzip --file "$archive_path" \
    --exclude='myrice/.git' --exclude='myrice/.git/**' \
    --exclude='myrice/vm/.state' --exclude='myrice/vm/.state/**' \
    --exclude='myrice/__pycache__' --exclude='myrice/**/__pycache__' \
    --exclude='myrice/.pytest_cache' --exclude='myrice/**/.pytest_cache' \
    -C "$(dirname "$repo_dir")" myrice
  tar -tzf "$archive_path" >/dev/null
}

key_file="$state_dir/cloud_ed25519"
ssh_base=(ssh -i "$key_file" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 -o LogLevel=ERROR -p 2223 arch@127.0.0.1)
scp_base=(scp -i "$key_file" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 -o LogLevel=ERROR -P 2223)

if [[ $acceptance_only -eq 1 ]]; then
  [[ -f "$state_dir/.myrice-cloud-state" ]] || die "refusing unmarked cloud state: $state_dir"
  [[ -f "$key_file" ]] || die "transient cloud key is missing: $key_file"
elif [[ $resume_install -eq 1 ]]; then
  [[ -f "$state_dir/.myrice-cloud-state" ]] || die "refusing unmarked cloud state: $state_dir"
  [[ -f "$state_dir/overlay.qcow2" && -r "$state_dir/overlay.qcow2" ]] || die "cloud overlay is missing or unreadable: $state_dir/overlay.qcow2"
  [[ -f "$state_dir/OVMF_VARS.fd" && -r "$state_dir/OVMF_VARS.fd" ]] || die "cloud OVMF variables are missing or unreadable: $state_dir/OVMF_VARS.fd"
  [[ -f "$key_file" && -r "$key_file" ]] || die "transient cloud key is missing or unreadable: $key_file"
  qemu-system-x86_64 \
    -enable-kvm -machine q35,accel=kvm -cpu host -smp 4 -m 4096 \
    -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code" \
    -drive "if=pflash,format=raw,file=$state_dir/OVMF_VARS.fd" \
    -drive "if=virtio,format=qcow2,file=$state_dir/overlay.qcow2" \
    -display none -serial "file:$state_dir/serial-install.log" \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2223-:22 \
    -name myrice-cloud-real-install >"$state_dir/qemu-install.log" 2>&1 & qemu_pid=$!
else
  requested_image="$image"
  image="$(realpath -e -- "$requested_image")" || die "image does not exist: $requested_image"
  [[ -f "$image" && -r "$image" ]] || die "image is not a readable file: $image"
  [[ ! -e "$state_dir" ]] || die "cloud state already exists: $state_dir; use --reset --yes before creating a new overlay"
  mkdir -p -m 700 -- "$state_dir"
  printf '%s\n' 'myrice-cloud-state-v1' > "$state_dir/.myrice-cloud-state"
  chmod 600 "$state_dir/.myrice-cloud-state"
  qemu-img create -f qcow2 -F qcow2 -b "$image" "$state_dir/overlay.qcow2"
  qemu-img resize "$state_dir/overlay.qcow2" "$disk_size"
  cp --reflink=auto -- "$ovmf_vars" "$state_dir/OVMF_VARS.fd"
  ssh-keygen -q -t ed25519 -N '' -f "$key_file"
  chmod 600 "$key_file" "$key_file.pub"

  staging_dir="$state_dir/staging"
  mkdir -p -m 700 -- "$staging_dir/cloud"
  log 'archiving the current worktree for the guest'
  create_source_archive "$staging_dir/myrice-source.tar.gz"
  public_key="$(<"$key_file.pub")"
  cat > "$staging_dir/cloud/meta-data" <<EOF
instance-id: myrice-cloud-disposable
local-hostname: myrice-cloud
EOF
  cat > "$staging_dir/cloud/user-data" <<EOF
#cloud-config
ssh_pwauth: false
disable_root: true
bootcmd:
  - [ sh, -c, "printf '%s\\n' 'Server = https://mirror.yandex.ru/archlinux/\$repo/os/\$arch' 'Server = https://mirror.23m.com/archlinux/\$repo/os/\$arch' > /etc/pacman.d/mirrorlist" ]
packages:
  - git
users:
  - name: arch
    groups: [wheel]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - ${public_key}
runcmd:
  - [ sh, -c, 'set -eu; mkdir -p /home/arch; curl -fsSL http://10.0.2.2:${port}/myrice-source.tar.gz -o /tmp/myrice-source.tar.gz; tar -tzf /tmp/myrice-source.tar.gz >/dev/null; tar -xzf /tmp/myrice-source.tar.gz -C /home/arch; chown -R arch:arch /home/arch/myrice; rm -f /tmp/myrice-source.tar.gz' ]
EOF
  chmod 600 "$staging_dir/cloud/user-data"
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$staging_dir" >"$state_dir/http.log" 2>&1 & http_pid=$!
  wait_for 'localhost-only HTTP server' curl --fail --silent "http://127.0.0.1:$port/cloud/meta-data" >/dev/null
  qemu-system-x86_64 \
    -enable-kvm -machine q35,accel=kvm -cpu host -smp 4 -m 4096 \
    -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code" \
    -drive "if=pflash,format=raw,file=$state_dir/OVMF_VARS.fd" \
    -drive "if=virtio,format=qcow2,file=$state_dir/overlay.qcow2" \
    -display none -serial "file:$state_dir/serial.log" \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2223-:22 \
    -smbios "type=1,serial=ds=nocloud-net;s=http://10.0.2.2:$port/cloud/" \
    -name myrice-cloud-acceptance >"$state_dir/qemu.log" 2>&1 & qemu_pid=$!
fi

log 'waiting for SSH with the generated cloud-state identity'
wait_for 'guest SSH' "${ssh_base[@]}" true
if [[ $resume_install -eq 1 ]]; then
  staging_dir="$state_dir/resume-staging"
  rm -rf -- "$staging_dir"
  mkdir -p -m 700 -- "$staging_dir"
  log 'archiving the current worktree for resume'
  create_source_archive "$staging_dir/myrice-source.tar.gz"
  log 'uploading and replacing the guest checkout from the sanitized source archive'
  "${scp_base[@]}" "$staging_dir/myrice-source.tar.gz" arch@127.0.0.1:/tmp/myrice-source.tar.gz
  "${ssh_base[@]}" 'set -eu; archive=/tmp/myrice-source.tar.gz; next=/home/arch/myrice.next; previous=/home/arch/myrice.previous; tar -tzf "$archive" >/dev/null; tar -tzf "$archive" | grep -qx "myrice/bootstrap.sh"; rm -rf "$next" "$previous"; mkdir -p "$next"; tar -xzf "$archive" -C "$next" --strip-components=1; test -x "$next/bootstrap.sh"; chown -R arch:arch "$next"; if test -e /home/arch/myrice; then mv /home/arch/myrice "$previous"; fi; mv "$next" /home/arch/myrice; rm -rf "$previous"; rm -f "$archive"' || die 'failed to validate and replace guest source archive; refusing to run bootstrap'
  "${ssh_base[@]}" 'test -x /home/arch/myrice/bootstrap.sh' || die 'guest bootstrap.sh is missing or not executable; refusing to run bootstrap'
  log 'clearing a stale guest pacman lock when no pacman process owns it'
  "${ssh_base[@]}" 'if test -e /var/lib/pacman/db.lck && (! command -v pgrep >/dev/null 2>&1 || ! pgrep -x pacman >/dev/null 2>&1); then sudo -n rm -f /var/lib/pacman/db.lck; fi'
  log "waiting up to ${timeout_seconds}s for the guest pacman database lock"
  wait_for 'guest pacman database lock release' "${ssh_base[@]}" 'test ! -e /var/lib/pacman/db.lck && (! command -v pgrep >/dev/null 2>&1 || ! pgrep -x pacman >/dev/null 2>&1)'
  install_status=0
  install_command='cd /home/arch/myrice && sudo -n true && set -o pipefail && /home/arch/myrice/bootstrap.sh bootstrap --non-interactive 2>&1 | tee /home/arch/real-install.log'
  log "running real guest bootstrap (timeout: ${install_timeout_seconds}s)"
  if command -v timeout >/dev/null 2>&1; then
    timeout --foreground "$install_timeout_seconds" "${ssh_base[@]}" "$install_command" || install_status=$?
  else
    "${ssh_base[@]}" "$install_command" || install_status=$?
  fi
  rm -rf -- "$state_dir/evidence-real-install"
  mkdir -p -- "$state_dir/evidence-real-install"
  "${scp_base[@]}" arch@127.0.0.1:/home/arch/real-install.log "$state_dir/evidence-real-install/"
  [[ $install_status -eq 0 ]] || die "guest real bootstrap failed with status $install_status"

  verification_status=0
  verification_command='set -o pipefail && { command -v Hyprland; pacman -Q hyprland quickshell hyprpaper hyprlock hypridle; for path in /home/arch/.config/hypr /home/arch/.config/quickshell; do test -L "$path" || { printf "not a symlink: %s\\n" "$path" >&2; exit 1; }; target=$(realpath -e -- "$path") || exit 1; case "$target" in /home/arch/myrice/*) printf "%s -> %s\\n" "$path" "$target" ;; *) printf "symlink outside myrice: %s -> %s\\n" "$path" "$target" >&2; exit 1 ;; esac; done; } 2>&1 | tee /home/arch/real-install-verification.log'
  "${ssh_base[@]}" "$verification_command" || verification_status=$?
  "${scp_base[@]}" arch@127.0.0.1:/home/arch/real-install-verification.log "$state_dir/evidence-real-install/"
  [[ $verification_status -eq 0 ]] || die "guest real-install verification failed with status $verification_status"
  log 'guest real bootstrap and verification passed'
  exit 0
fi
log 'waiting for cloud-init completion and the staged acceptance script'
wait_for 'cloud-init and acceptance script' "${ssh_base[@]}" 'test -f /var/lib/cloud/instance/boot-finished && test -x /home/arch/myrice/vm/acceptance.sh'
rm -rf -- "$state_dir/evidence"
mkdir -p -- "$state_dir/evidence"
acceptance_status=0
"${ssh_base[@]}" '/home/arch/myrice/vm/acceptance.sh --repo /home/arch/myrice --evidence-dir /home/arch/evidence' || acceptance_status=$?
"${scp_base[@]}" -r arch@127.0.0.1:/home/arch/evidence/. "$state_dir/evidence/"
for evidence_log in plan doctor bootstrap-dry-run; do
  [[ -s "$state_dir/evidence/$evidence_log.log" ]] || die "missing or empty acceptance log: $evidence_log.log"
done
[[ -s "$state_dir/evidence/metadata.txt" ]] || die 'missing or empty acceptance metadata.txt'
[[ $acceptance_status -eq 0 ]] || die "guest acceptance failed with status $acceptance_status"
log 'guest acceptance passed'
