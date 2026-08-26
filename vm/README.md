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

## Cloud-image disposable provisioning

`cloud-provision.sh` is a separate, fully headless NoCloud path for a local
Arch cloud qcow2 image. It does not replace or modify the ISO/QMP harness
above. It copies OVMF variables, creates a qcow2 overlay (never changing the
supplied image), generates a new state-local SSH identity, and transfers a
sanitized archive of the current worktree through localhost-only user-mode NAT.

```bash
./vm/cloud-provision.sh --image vm/.state/Arch-Linux-x86_64-cloudimg.qcow2
./vm/cloud-provision.sh --image vm/.state/Arch-Linux-x86_64-cloudimg.qcow2 --acceptance-only
./vm/cloud-provision.sh --image vm/.state/Arch-Linux-x86_64-cloudimg.qcow2 --resume-install
./vm/cloud-provision.sh --image /any/path --dry-run
./vm/cloud-provision.sh --image vm/.state/Arch-Linux-x86_64-cloudimg.qcow2 --reset --yes
```

Cloud state is owned only below `vm/.state/cloud` (or a descendant selected by
`MYRICE_CLOUD_VM_DIR`) and is marked before it can be reset. The guest SSH port
is `127.0.0.1:2223`; the script uses only its generated key with
`IdentitiesOnly=yes`. It waits for both cloud-init completion and the archived
acceptance script, then saves `plan.log`, `doctor.log`, and
`bootstrap-dry-run.log` under the cloud state evidence directory. Set
`MYRICE_VM_TIMEOUT` (default `900`) or `MYRICE_CLOUD_VM_HTTP_PORT` if needed.
On initial state creation, the disposable overlay is resized to
`MYRICE_CLOUD_VM_DISK_SIZE` (default `12G`) before its first boot, so cloud-init
can grow the root filesystem. Its value must be a positive integer with a `G`
or `M` suffix, such as `12G` or `4096M`. The supplied image and backing source
are never resized. Changing the size of an existing cloud state requires
`--reset --yes` and a new initial boot; `--resume-install` never resizes its
existing overlay.

`--resume-install` requires an existing marked cloud state and the original
overlay, OVMF variables, and generated SSH key. It neither reads nor modifies
the supplied image, creates NoCloud data, or starts HTTP. It boots that overlay
on port `2223`. Before every real bootstrap, it creates a validated sanitized
archive from the current host worktree using the normal cloud archive exclusions
and transfers it only over the transient-key SCP connection. The guest validates
the uploaded `/tmp` archive, extracts it into `/home/arch/myrice.next`, then
replaces `/home/arch/myrice` (keeping only the brief rename window); guest logs
and evidence outside that checkout are unaffected. The temporary host archive
remains only under marked cloud state and is cleaned up on exit; no host
directory is mounted or exposed to the guest. It then runs
`/home/arch/myrice/bootstrap.sh bootstrap --non-interactive` as the normal
`arch` user from `/home/arch/myrice`; this explicitly accepts pacman's package
choices only inside the disposable VM. It always stops the QEMU process it
started. Its install SSH command has a separate
`MYRICE_VM_INSTALL_TIMEOUT` (default `7200` seconds; no timeout is imposed if
the host lacks `timeout`). Before that bootstrap, resume waits up to
`MYRICE_VM_TIMEOUT` for the pacman lock and any `pacman` process to clear and,
when cloud-init is present, for its final boot marker. On success,
`real-install.log` and package/symlink verification are copied to
`vm/.state/cloud/evidence-real-install/`.
