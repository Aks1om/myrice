# Isolated QEMU/KVM acceptance harness

This directory provides a local QEMU/KVM harness for testing MyRice in an
isolated VM. It is separate from the installer: it does **not** modify the
host's `/etc`, bootloader, packages, `$HOME`, SSH configuration, or mounts.
The VM has only a blank qcow2 disk, UEFI variables stored under `vm/.state`, a
virtio GPU, and QEMU user-mode NAT networking. Host HOME, SSH keys, SSH agent,
and repository files are never mounted into the guest. Automated provisioning
uses QEMU's UNIX QMP socket instead of `wtype` or GUI/host keyboard typing.

## Prerequisites

- `qemu-system-x86_64` and `qemu-img`
- accessible `/dev/kvm` (virtualization enabled and the current user permitted)
- an OVMF/edk2-ovmf package providing matching `OVMF_CODE.fd` and `OVMF_VARS.fd`
- an Arch ISO you have downloaded yourself
- `sshpass` for password-only guest acceptance through the forwarded SSH port

Check everything without changing the host or creating VM files:

```bash
./vm/myrice-vm.sh check
```

The script searches common Arch, Fedora, and Debian-family OVMF locations. If
it cannot find the firmware pair, it exits with an installation hint.

## Lifecycle

No command downloads an ISO or installs Arch automatically. An ISO is accepted
only when supplied explicitly with `--iso`.

```bash
# Validate an explicit ISO path and create a blank 32 GiB base disk.
./vm/myrice-vm.sh create --iso /path/to/archlinux.iso --disk 32G

# Create a disposable qcow2 overlay backed by that base disk.
./vm/myrice-vm.sh overlay

# Boot the installer ISO with 4 GiB RAM and four vCPUs. QMP defaults to
# vm/.state/qmp.sock; guest SSH is forwarded to 127.0.0.1:2222.
./vm/myrice-vm.sh run --iso /path/to/archlinux.iso --ram 4096 --cpus 4

# After the guest is installed, boot its overlay without an ISO.
./vm/myrice-vm.sh run
```

`create` refuses to overwrite existing state. `destroy` and `clean` are the
only destructive commands and require explicit confirmation:

```bash
./vm/myrice-vm.sh destroy --yes
```

By default all mutable VM artifacts are in ignored `vm/.state/`. Set
`MYRICE_VM_DIR=/safe/path` to place them elsewhere. The base disk remains
unchanged after an overlay is created; reset the complete harness state with
`destroy --yes` and recreate it when a fresh base is needed.

## Automated disposable provisioning

The ISO-only provisioner temporarily serves only a staged guest installer and
sanitized source archive on `127.0.0.1`, boots the ISO in the harness, and
QMP-types this short command into its console:

```text
curl -fsSL http://10.0.2.2:PORT/vm/install-guest.sh | bash
```

The guest installer refuses to run without the Arch ISO marker and `/dev/vda`.
It creates a disposable GPT disk with UEFI/systemd-boot, FAT EFI and ext4 root;
then configures `arch`/`arch`, NOPASSWD wheel, NetworkManager, and sshd. Before
starting its temporary HTTP server, the provisioner archives the current
worktree as `vm/.state/myrice-source.tar.gz` in that staging directory; the
installer downloads, verifies, and extracts it to `/home/arch/myrice` before
rebooting. The temporary staging directory is removed during cleanup.

```bash
./vm/provision.sh --iso /path/to/archlinux.iso
./vm/provision.sh --acceptance-only
./vm/provision.sh --iso /path/to/archlinux.iso --dry-run
```

The provisioner has an explicit 900-second default timeout
(`MYRICE_VM_TIMEOUT`) and waits 45 seconds for the ISO autologin shell before
QMP typing (`MYRICE_VM_BOOT_WAIT`, positive integer). It logs under its owned
VM state and cleans the temporary HTTP server, QEMU process it started, and QMP
socket. `--acceptance-only` connects only to an already-running guest on
`127.0.0.1:2222`. Provisioning runs guest acceptance from
`/home/arch/myrice`, copies evidence to `vm/.state/evidence`, verifies the
plan, doctor, and bootstrap dry-run logs, and only then stops QEMU.

`qmp-type.py` is stdlib-only and its mapping can be inspected without a VM:

```bash
python3 vm/qmp-type.py --socket vm/.state/qmp.sock --dry-run 'echo hello'
```

## Guest acceptance evidence

After manually installing Arch, cloning/copying this repository inside the
guest, and booting that guest, run:

```bash
./vm/acceptance.sh --evidence-dir "$HOME/myrice-acceptance-evidence"
```

The guest-only script runs `bootstrap.sh plan`, `bootstrap.sh doctor`, and
`bootstrap.sh bootstrap --dry-run`; it saves separate logs plus metadata. It
does not install packages or download anything. Review the dry-run output
before choosing any real bootstrap action.
