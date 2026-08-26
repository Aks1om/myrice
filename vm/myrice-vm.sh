#!/usr/bin/env bash
# Local QEMU/KVM harness for acceptance testing. It never mounts host files.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vm_dir="${MYRICE_VM_DIR:-$repo_dir/vm/.state}"
disk_size="32G"
memory="4096"
cpus="4"
iso=""
qmp_socket=""
command_name="${1:-help}"

usage() {
  cat <<'EOF'
Usage: vm/myrice-vm.sh COMMAND [options]

Commands:
  check                 Validate QEMU/KVM and OVMF prerequisites without changes.
  create --iso PATH     Create a blank qcow2 base disk and per-VM UEFI variables.
  overlay               Create the disposable qcow2 overlay backed by the base disk.
  run [--iso PATH]      Boot the overlay with UEFI, KVM, QMP, and user-mode NAT.
  destroy --yes         Delete this harness's VM state directory.
  clean --yes           Alias for destroy.

Options for create/run:
  --iso PATH            Explicit local ISO path. The harness never downloads an ISO.
  --disk SIZE           Base disk size for create (default: 32G).
  --ram MiB             Guest RAM for run (default: 4096).
  --cpus COUNT          Guest vCPU count for run (default: 4).
  --qmp-socket PATH     QMP UNIX socket for run (default: VM state/qmp.sock).
  -h, --help            Show this help.

Set MYRICE_VM_DIR to keep VM state outside the repository. No host HOME, SSH
agent, SSH keys, or host directories are mounted into the guest.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_value() {
  [[ $# -eq 2 && -n "$2" ]] || die "$1 requires a value"
}

parse_options() {
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iso) require_value --iso "${2:-}"; iso="$2"; shift;;
      --disk) require_value --disk "${2:-}"; disk_size="$2"; shift;;
      --ram) require_value --ram "${2:-}"; memory="$2"; shift;;
       --cpus) require_value --cpus "${2:-}"; cpus="$2"; shift;;
       --qmp-socket) require_value --qmp-socket "${2:-}"; qmp_socket="$2"; shift;;
      -h|--help) usage; exit 0;;
      *) die "unknown option: $1";;
    esac
    shift
  done
}

ovmf_code=""
ovmf_vars=""
detect_ovmf() {
  local code_candidate vars_candidate
  local -a code_paths=(
    /usr/share/edk2/x64/OVMF_CODE.4m.fd
    /usr/share/edk2/x64/OVMF_CODE.fd
    /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
    /usr/share/OVMF/OVMF_CODE.fd
    /usr/share/edk2/ovmf/OVMF_CODE.fd
  )
  for code_candidate in "${code_paths[@]}"; do
    vars_candidate="${code_candidate/OVMF_CODE/OVMF_VARS}"
    if [[ -r "$code_candidate" && -r "$vars_candidate" ]]; then
      ovmf_code="$code_candidate"
      ovmf_vars="$vars_candidate"
      return 0
    fi
  done
  return 1
}

check_requirements() {
  local missing=0
  for tool in qemu-system-x86_64 qemu-img; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'error: required command not found: %s\n' "$tool" >&2
      missing=1
    fi
  done
  if [[ ! -e /dev/kvm ]]; then
    printf '%s\n' 'error: /dev/kvm is missing; enable VT-x/AMD-V and load the KVM module.' >&2
    missing=1
  elif [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    printf '%s\n' 'error: /dev/kvm is not accessible; add the current user to the kvm group and re-login.' >&2
    missing=1
  fi
  if ! detect_ovmf; then
    printf '%s\n' 'error: OVMF_CODE.fd and OVMF_VARS.fd were not found in known locations; install your distribution OVMF/edk2-ovmf package.' >&2
    missing=1
  fi
  [[ $missing -eq 0 ]] || exit 1
  printf 'QEMU: %s\n' "$(command -v qemu-system-x86_64)"
  printf 'qemu-img: %s\n' "$(command -v qemu-img)"
  printf 'KVM: /dev/kvm accessible\n'
  printf 'OVMF_CODE: %s\n' "$ovmf_code"
  printf 'OVMF_VARS: %s\n' "$ovmf_vars"
}

resolve_iso() {
  [[ -n "$iso" ]] || die 'create requires an explicit --iso PATH; no ISO is downloaded automatically'
  iso="$(realpath -e -- "$iso")" || die "ISO does not exist: $iso"
  [[ -f "$iso" && -r "$iso" ]] || die "ISO is not a readable file: $iso"
}

state_file() {
  printf '%s/%s\n' "$vm_dir" "$1"
}

require_state() {
  [[ -f "$(state_file .myrice-vm-state)" ]] || die "VM state is absent: $vm_dir (run create first)"
}

create_vm() {
  check_requirements
  resolve_iso
  [[ "$vm_dir" != / && "$vm_dir" != "$repo_dir" && "$vm_dir" != "$repo_dir/vm" ]] || die "unsafe VM state path: $vm_dir"
  if [[ -e "$vm_dir" ]]; then
    die "VM state already exists: $vm_dir; use overlay, run, or destroy --yes"
  fi
  mkdir -p -- "$vm_dir"
  qemu-img create -f qcow2 "$(state_file base.qcow2)" "$disk_size"
  cp --reflink=auto -- "$ovmf_vars" "$(state_file OVMF_VARS.fd)"
  printf 'myrice-vm-state-v1\n' > "$(state_file .myrice-vm-state)"
  printf 'Created blank base disk: %s\n' "$(state_file base.qcow2)"
  printf 'ISO validated but not copied or booted: %s\n' "$iso"
  printf '%s\n' 'Next: run vm/myrice-vm.sh overlay, then vm/myrice-vm.sh run --iso /path/to/archlinux.iso'
}

create_overlay() {
  check_requirements
  require_state
  local base overlay
  base="$(state_file base.qcow2)"
  overlay="$(state_file overlay.qcow2)"
  [[ -f "$base" ]] || die "base disk is missing: $base"
  [[ ! -e "$overlay" ]] || die "overlay already exists: $overlay; destroy --yes to reset all VM state"
  qemu-img create -f qcow2 -F qcow2 -b "$base" "$overlay"
  printf 'Created disposable overlay: %s\n' "$overlay"
}

run_vm() {
  check_requirements
  require_state
  local overlay vars
  overlay="$(state_file overlay.qcow2)"
  vars="$(state_file OVMF_VARS.fd)"
  [[ -f "$overlay" ]] || die "overlay is missing: $overlay (run overlay first)"
  [[ -f "$vars" ]] || die "UEFI variables are missing: $vars"
  if [[ -z "$qmp_socket" ]]; then
    qmp_socket="$(state_file qmp.sock)"
  fi
  [[ -S "$qmp_socket" || ! -e "$qmp_socket" ]] || die "QMP path exists but is not a socket: $qmp_socket"
  rm -f -- "$qmp_socket"
  local -a qemu_args=(
    -enable-kvm
    -machine q35,accel=kvm
    -cpu host
    -smp "$cpus"
    -m "$memory"
    -drive "if=pflash,format=raw,readonly=on,file=$ovmf_code"
    -drive "if=pflash,format=raw,file=$vars"
    -drive "if=virtio,format=qcow2,file=$overlay"
    -device virtio-vga
    -display gtk
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22
    -qmp "unix:$qmp_socket,server=on,wait=off"
    -name myrice-acceptance
  )
  if [[ -n "$iso" ]]; then
    resolve_iso
    qemu_args+=( -boot once=d -drive "media=cdrom,readonly=on,file=$iso" )
  fi
  printf '%s\n' 'Starting an isolated VM: user-mode NAT only; no host directories, HOME, or SSH agent are shared.'
  exec qemu-system-x86_64 "${qemu_args[@]}"
}

destroy_vm() {
  [[ "${1:-}" == --yes ]] || die 'destroy is destructive; rerun as: vm/myrice-vm.sh destroy --yes'
  [[ "$vm_dir" != / && "$vm_dir" != "$repo_dir" && "$vm_dir" != "$repo_dir/vm" ]] || die "unsafe VM state path: $vm_dir"
  require_state
  rm -rf -- "$vm_dir"
  printf 'Deleted VM state: %s\n' "$vm_dir"
}

case "$command_name" in
  check) parse_options "$@"; check_requirements;;
  create) parse_options "$@"; create_vm;;
  overlay) parse_options "$@"; create_overlay;;
  run) parse_options "$@"; run_vm;;
  destroy|clean) shift; destroy_vm "$@";;
  help|-h|--help|'') usage;;
  *) die "unknown command: $command_name (try: vm/myrice-vm.sh help)";;
esac
