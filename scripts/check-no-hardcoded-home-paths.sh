#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The disposable VM guest extracts the worktree here (see vm/README.md).
guest_user=arch
guest_fixture="/home/$guest_user/myrice"
found=0
while IFS= read -r match; do
  case "$match" in
    "$repo_dir"/vm/install-guest.sh:"$guest_fixture"|"$repo_dir"/vm/install-guest.sh:"$guest_fixture"/*|"$repo_dir"/vm/provision.sh:"$guest_fixture"|"$repo_dir"/vm/provision.sh:"$guest_fixture"/*|"$repo_dir"/vm/cloud-provision.sh:"/home/$guest_user"|"$repo_dir"/vm/cloud-provision.sh:"/home/$guest_user"/*) continue;;
  esac
  printf '%s\n' "$match" >&2
  found=1
done < <(rg -P -o --with-filename --glob '!scripts/__pycache__/**' --glob '*.{sh,py,hl,qml,desktop,service,conf}' '(?<!REPO_DIR")(?<![A-Za-z0-9_}$])/home/[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*' "$repo_dir" || true)
if (( found )); then
  printf '%s\n' 'hardcoded home paths found' >&2
  exit 1
fi
printf '%s\n' 'no hardcoded home paths found'
