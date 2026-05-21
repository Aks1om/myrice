#!/usr/bin/env bash
# Add `pcie_aspm=off` to every systemd-boot loader entry that boots a `linux` kernel
# (i.e. entries whose `options` line refers to the user's local root device).
#
# Why: on the RTL8821CE Wi-Fi chip with the in-kernel rtw88 driver, PCIe ASPM
# triggers persistent disconnects ("failed to get tx report from firmware").
# Disabling ASPM at the bus level pairs with the out-of-tree 8821ce driver to
# stabilise the link. Harmless on other hardware (some marginal idle-power loss).
#
# Safe to re-run: skips entries that already contain `pcie_aspm=off`.

set -euo pipefail

ENTRIES_DIR="/boot/loader/entries"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ ! -d "$ENTRIES_DIR" ]]; then
  echo "No $ENTRIES_DIR found — systemd-boot doesn't seem to be in use. Skipping." >&2
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

shopt -s nullglob
patched=0
for entry in "$ENTRIES_DIR"/*.conf; do
  if grep -q '^options.*pcie_aspm=off' "$entry"; then
    continue
  fi
  if ! grep -q '^options.*root=' "$entry"; then
    continue
  fi
  cp -a "$entry" "${entry}.bak-${STAMP}"
  sed -i 's|^options |options pcie_aspm=off |' "$entry"
  echo "patched: $entry  (backup: ${entry}.bak-${STAMP})"
  patched=$((patched + 1))
done

if [[ $patched -eq 0 ]]; then
  echo "Nothing to patch — all eligible entries already carry pcie_aspm=off."
fi
