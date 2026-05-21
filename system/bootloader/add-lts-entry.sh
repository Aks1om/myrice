#!/usr/bin/env bash
# Add a systemd-boot entry for linux-lts that mirrors the default entry's
# options (root=, pcie_aspm=off, plymouth flags, etc.), so a broken main
# kernel never leaves you stranded.
#
# Picks the entry pointed at by `default` in /boot/loader/loader.conf
# (falls back to the first `*linux*.conf` that boots the `linux` kernel)
# and emits /boot/loader/entries/arch-linux-lts.conf with the same options
# but `linux /vmlinuz-linux-lts` and `initrd /initramfs-linux-lts.img`.
#
# Safe to re-run: skips if the LTS entry already exists.

set -euo pipefail

LOADER_DIR="/boot/loader"
ENTRIES_DIR="$LOADER_DIR/entries"
LTS_ENTRY="$ENTRIES_DIR/arch-linux-lts.conf"

if [[ ! -d "$ENTRIES_DIR" ]]; then
  echo "No $ENTRIES_DIR — systemd-boot doesn't seem to be in use. Skipping." >&2
  exit 0
fi
if [[ ! -e /boot/vmlinuz-linux-lts || ! -e /boot/initramfs-linux-lts.img ]]; then
  echo "vmlinuz-linux-lts / initramfs-linux-lts.img missing under /boot — install linux-lts first." >&2
  exit 1
fi
if [[ -e "$LTS_ENTRY" ]]; then
  echo "$LTS_ENTRY already present — nothing to do."
  exit 0
fi
if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

default_entry=""
if [[ -r "$LOADER_DIR/loader.conf" ]]; then
  default_entry="$(awk '/^default /{print $2; exit}' "$LOADER_DIR/loader.conf")"
fi
src=""
if [[ -n "$default_entry" && -f "$ENTRIES_DIR/$default_entry" ]]; then
  src="$ENTRIES_DIR/$default_entry"
else
  # Heuristic: pick a non-fallback entry whose `linux` line points at
  # /vmlinuz-linux (the stock kernel package, not LTS / EndeavourOS / etc.).
  for f in "$ENTRIES_DIR"/*.conf; do
    [[ "$f" == "$LTS_ENTRY" ]] && continue
    if grep -qE '^linux\s+/vmlinuz-linux($|\s)' "$f" 2>/dev/null; then
      src="$f"
      break
    fi
  done
fi
if [[ -z "$src" ]]; then
  echo "Couldn't locate a stock-kernel boot entry to mirror — aborting." >&2
  exit 1
fi

opts="$(awk '/^options /{sub(/^options /, ""); print; exit}' "$src")"
if [[ -z "$opts" ]]; then
  echo "Source entry $src has no 'options' line — aborting." >&2
  exit 1
fi

cat > "$LTS_ENTRY" <<EOF
title   Arch Linux (linux-lts, fallback)
linux   /vmlinuz-linux-lts
initrd  /amd-ucode.img
initrd  /initramfs-linux-lts.img
options $opts
EOF

# Drop the ucode initrd line if amd-ucode isn't present (Intel/no-ucode boxes).
if [[ ! -e /boot/amd-ucode.img ]]; then
  sed -i '/^initrd\s*\/amd-ucode.img$/d' "$LTS_ENTRY"
fi

echo "Wrote $LTS_ENTRY (mirrored from $(basename "$src"))"
