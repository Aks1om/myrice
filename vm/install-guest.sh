#!/usr/bin/env bash
# Disposable Arch ISO guest installer. Never run this script on the host.
set -euo pipefail

http_base="${1:-${MYRICE_HTTP_BASE:-http://10.0.2.2:18080}}"
target=/mnt
die() { printf 'install-guest: %s\n' "$*" >&2; exit 1; }

[[ -d /run/archiso ]] || die 'refusing to run outside an Arch ISO environment (/run/archiso is absent)'
[[ -b /dev/vda ]] || die 'refusing to run: disposable VM disk /dev/vda is absent'
[[ "$(findmnt -n -o SOURCE / 2>/dev/null || true)" != /dev/vda* ]] || die 'refusing to install onto the current root disk'
if [[ -n "$http_base" ]]; then
  http_base="${http_base%/}"
  [[ "$http_base" =~ ^https?:// ]] || die 'HTTP base URL must start with http:// or https://'
fi

cleanup_mounts() {
  if findmnt -rn --target "$target" >/dev/null 2>&1; then
    umount -R "$target"
  fi
}
trap cleanup_mounts EXIT

timedatectl set-ntp true
cat > /etc/pacman.d/mirrorlist <<'MIRRORS'
Server = https://mirror.yandex.ru/archlinux/$repo/os/$arch
Server = https://mirror.truenetwork.ru/archlinux/$repo/os/$arch
Server = https://mirror.23m.com/archlinux/$repo/os/$arch
MIRRORS
pacman -Syy --noconfirm archlinux-keyring
cleanup_mounts
sgdisk --zap-all /dev/vda
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:EFI /dev/vda
sgdisk -n 2:0:0 -t 2:8300 -c 2:root /dev/vda
mkfs.fat -F 32 -n EFI /dev/vda1
mkfs.ext4 -F -L arch-root /dev/vda2
mount /dev/vda2 "$target"
mkdir -p "$target/boot"
mount /dev/vda1 "$target/boot"
pacstrap -K "$target" base linux linux-firmware networkmanager openssh sudo curl ca-certificates
genfstab -U "$target" >> "$target/etc/fstab"
arch-chroot "$target" /bin/bash -euo pipefail <<'CHROOT'
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
printf '%s\n' 'LANG=en_US.UTF-8' > /etc/locale.conf
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
printf '%s\n' arch > /etc/hostname
printf '%s\n' '127.0.0.1 localhost' '::1 localhost' '127.0.1.1 arch.localdomain arch' > /etc/hosts
id arch >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash arch
printf '%s\n' 'arch:arch' | chpasswd
install -d -m 0750 /etc/sudoers.d
printf '%s\n' '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-wheel-nopasswd
chmod 0440 /etc/sudoers.d/10-wheel-nopasswd
visudo -cf /etc/sudoers.d/10-wheel-nopasswd
install -d -m 0755 /etc/ssh/sshd_config.d
printf '%s\n' 'PasswordAuthentication yes' 'PermitRootLogin no' > /etc/ssh/sshd_config.d/10-myrice-vm.conf
systemctl enable NetworkManager sshd
bootctl --path=/boot install
root_uuid="$(blkid -s UUID -o value /dev/vda2)"
[[ -n "$root_uuid" ]] || { printf '%s\n' 'unable to determine /dev/vda2 UUID' >&2; exit 1; }
install -d -m 0755 /boot/loader/entries
cat > /boot/loader/loader.conf <<'LOADER'
default arch.conf
timeout 0
console-mode keep
editor no
LOADER
cat > /boot/loader/entries/arch.conf <<ENTRY
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=${root_uuid} rw
ENTRY
CHROOT
if [[ -n "$http_base" ]]; then
  install -d -m 0755 "$target/home/arch"
  source_archive="$target/home/arch/myrice-source.tar.gz"
  curl --fail --silent --show-error --location "$http_base/vm/.state/myrice-source.tar.gz" -o "$source_archive"
  tar -tzf "$source_archive" >/dev/null
  tar -tzf "$source_archive" | grep -qx 'myrice/' || die 'source archive is missing the myrice top-level directory'
  tar -xzf "$source_archive" -C "$target/home/arch"
  [[ -d "$target/home/arch/myrice" ]] || die 'source archive did not contain /home/arch/myrice'
  chown -R 1000:1000 "$target/home/arch/myrice"
  rm -f -- "$source_archive"
fi
sync
cleanup_mounts
trap - EXIT
printf '%s\n' 'install-guest: installation complete; rebooting the disposable VM'
reboot
