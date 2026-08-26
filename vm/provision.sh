#!/usr/bin/env bash
# Host-side disposable VM provisioner. It only controls this harness's state.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
harness="$repo_dir/vm/myrice-vm.sh"
qmp_type="$repo_dir/vm/qmp-type.py"
vm_dir="${MYRICE_VM_DIR:-$repo_dir/vm/.state}"
iso=""; port="${MYRICE_VM_HTTP_PORT:-18080}"; timeout_seconds="${MYRICE_VM_TIMEOUT:-900}"
boot_wait_seconds="${MYRICE_VM_BOOT_WAIT:-45}"
dry_run=0; acceptance_only=0; http_pid=""; qemu_pid=""; qmp_socket_created=0; qmp_socket="$vm_dir/qmp.sock"
staging_dir=""; source_archive=""; evidence_dir="$vm_dir/evidence"
usage() { printf '%s\n' 'Usage: vm/provision.sh --iso PATH [--dry-run] [--acceptance-only]'; }
die() { printf 'provision: %s\n' "$*" >&2; exit 1; }
log() { printf 'provision: %s\n' "$*"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) [[ $# -ge 2 && -n "$2" ]] || die '--iso requires a path'; iso="$2"; shift;;
    --dry-run) dry_run=1;; --acceptance-only) acceptance_only=1;;
    -h|--help) usage; exit 0;; *) die "unknown option: $1";;
  esac
  shift
done
cleanup() {
  local status=$?
  [[ -z "$http_pid" ]] || kill "$http_pid" 2>/dev/null || true
  [[ -z "$qemu_pid" ]] || kill "$qemu_pid" 2>/dev/null || true
  [[ -z "$http_pid" ]] || wait "$http_pid" 2>/dev/null || true
  [[ -z "$qemu_pid" ]] || wait "$qemu_pid" 2>/dev/null || true
  [[ $qmp_socket_created -eq 0 ]] || rm -f -- "$qmp_socket"
  [[ -z "$staging_dir" ]] || rm -rf -- "$staging_dir"
  exit "$status"
}
trap cleanup EXIT INT TERM
wait_for() {
  local description="$1"; shift
  local deadline=$((SECONDS + timeout_seconds))
  until "$@"; do
    (( SECONDS < deadline )) || die "timed out waiting for $description after ${timeout_seconds}s"
    sleep 2
  done
}
ssh_command() {
  sshpass -p arch ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR arch@127.0.0.1 "$@"
}
scp_from_guest() {
  sshpass -p arch scp -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR -r "$@"
}
[[ "$port" =~ ^[0-9]{1,5}$ ]] && (( port > 0 && port < 65536 )) || die "invalid HTTP port: $port"
[[ "$boot_wait_seconds" =~ ^[0-9]+$ ]] && (( 10#$boot_wait_seconds > 0 )) || die "invalid VM boot wait: $boot_wait_seconds"
if [[ $acceptance_only -eq 0 ]]; then
  [[ -n "$iso" ]] || die '--iso is required unless --acceptance-only is used'
fi
if [[ $dry_run -eq 1 ]]; then
  log "would use VM state: $vm_dir"
  [[ $acceptance_only -eq 1 ]] || log "would stage a sanitized archive and guest installer for localhost-only serving on 127.0.0.1:$port before booting $iso"
  [[ $acceptance_only -eq 1 ]] || log "would wait ${boot_wait_seconds}s for Arch ISO autologin before typing guest installer command"
  python3 "$qmp_type" --socket "$qmp_socket" --dry-run "curl -fsSL http://10.0.2.2:$port/vm/install-guest.sh | bash"
  log "would run SSH acceptance from /home/arch/myrice, fetch evidence to $evidence_dir, and verify its logs"
  exit 0
fi
if [[ $acceptance_only -eq 0 ]]; then
  requested_iso="$iso"
  iso="$(realpath -e -- "$requested_iso")" || die "ISO does not exist: $requested_iso"
fi
command -v python3 >/dev/null || die 'python3 is required'
command -v sshpass >/dev/null || die 'sshpass is required for password-only guest acceptance'
command -v scp >/dev/null || die 'scp is required to fetch guest acceptance evidence'
if [[ $acceptance_only -eq 0 ]]; then
  command -v curl >/dev/null || die 'curl is required'
  command -v tar >/dev/null || die 'tar is required to archive the current worktree'
  if [[ ! -f "$vm_dir/.myrice-vm-state" ]]; then
    log 'creating marked disposable VM state'; "$harness" create --iso "$iso"; "$harness" overlay
  elif [[ ! -f "$vm_dir/overlay.qcow2" ]]; then
    log 'creating missing disposable overlay in existing marked state'; "$harness" overlay
  fi
  [[ -f "$vm_dir/.myrice-vm-state" ]] || die "refusing unmarked VM state: $vm_dir"
  staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/myrice-vm-http.XXXXXX")"
  source_archive="$staging_dir/vm/.state/myrice-source.tar.gz"
  mkdir -p -- "$staging_dir/vm/.state"
  cp -- "$repo_dir/vm/install-guest.sh" "$staging_dir/vm/install-guest.sh"
  log 'archiving the current worktree for guest acceptance'
  tar --create --gzip --file "$source_archive" \
    --exclude='myrice/.git' \
    --exclude='myrice/vm/.state' \
    --exclude='myrice/__pycache__' \
    --exclude='myrice/**/__pycache__' \
    --exclude='myrice/*.pyc' \
    --exclude='myrice/**/*.pyc' \
    --exclude='myrice/.config/quickshell/icons/phosphor' \
    --exclude='myrice/.dotfiles_backup_*' \
    --exclude='myrice/.myrice_backup_*' \
    --exclude='myrice/profiles/local' \
    --exclude='myrice/.idea' \
    --exclude='myrice/.ssh' \
    --exclude='myrice/home/.ssh' \
    --exclude='myrice/.env' \
    --exclude='myrice/.env.*' \
    -C "$(dirname "$repo_dir")" myrice
  log "starting localhost-only staged-artifact server on port $port"
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$staging_dir" >"$vm_dir/http.log" 2>&1 & http_pid=$!
  wait_for 'HTTP server' curl --fail --silent "http://127.0.0.1:$port/vm/install-guest.sh" >/dev/null
  log 'starting Arch ISO VM in the background'
  "$harness" run --iso "$iso" --qmp-socket "$qmp_socket" >"$vm_dir/qemu.log" 2>&1 & qemu_pid=$!; qmp_socket_created=1
  wait_for 'QMP socket' test -S "$qmp_socket"
  log "waiting ${boot_wait_seconds}s for Arch ISO autologin shell"
  sleep "$boot_wait_seconds"
  log 'typing guest installer command through QMP'
  python3 "$qmp_type" --socket "$qmp_socket" "curl -fsSL http://10.0.2.2:$port/vm/install-guest.sh | bash"
else
  [[ -f "$vm_dir/.myrice-vm-state" ]] || die "refusing unmarked VM state: $vm_dir"
fi
log 'waiting for SSH after guest installation/reboot'; wait_for 'guest SSH' ssh_command true
log 'checking guest prerequisites'
ssh_command 'set -e; test "$(id -un)" = arch; test -d /home/arch/myrice; sudo -n true; systemctl is-enabled NetworkManager sshd; systemctl is-active NetworkManager sshd; findmnt -n -o FSTYPE / | grep -qx ext4; findmnt -n -o FSTYPE /boot | grep -qx vfat'
rm -rf -- "$evidence_dir"
mkdir -p -- "$evidence_dir"
log 'running guest acceptance from the archived worktree'
acceptance_status=0
ssh_command '/home/arch/myrice/vm/acceptance.sh --repo /home/arch/myrice --evidence-dir "$HOME/evidence"' || acceptance_status=$?
log 'fetching guest acceptance evidence'
scp_from_guest arch@127.0.0.1:evidence/. "$evidence_dir/"
for evidence_log in plan doctor bootstrap-dry-run; do
  [[ -f "$evidence_dir/$evidence_log.log" ]] || die "missing guest acceptance log: $evidence_log.log"
done
[[ $acceptance_status -eq 0 ]] || die "guest acceptance failed with status $acceptance_status"
log 'guest acceptance passed'
