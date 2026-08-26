#!/usr/bin/env bash
# Run this inside an already-installed guest with a local myrice checkout.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
evidence_dir="${MYRICE_ACCEPTANCE_EVIDENCE_DIR:-$PWD/myrice-acceptance-evidence}"

usage() {
  cat <<'EOF'
Usage: vm/acceptance.sh [--repo PATH] [--evidence-dir PATH]

Runs read-only plan/doctor and bootstrap dry-run in a guest. It records stdout
and stderr in the selected evidence directory. It does not install packages,
download an ISO, or start a VM; the guest OS and repository checkout must
already exist.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 && -n "$2" ]] || { printf '%s\n' 'error: --repo requires a path' >&2; exit 2; }
      repo_dir="$(realpath -e -- "$2")" || { printf 'error: repository does not exist: %s\n' "$2" >&2; exit 1; }
      shift;;
    --evidence-dir)
      [[ $# -ge 2 && -n "$2" ]] || { printf '%s\n' 'error: --evidence-dir requires a path' >&2; exit 2; }
      evidence_dir="$2"
      shift;;
    -h|--help) usage; exit 0;;
    *) printf 'error: unknown option: %s\n' "$1" >&2; exit 2;;
  esac
  shift
done

[[ -x "$repo_dir/bootstrap.sh" ]] || { printf 'error: bootstrap.sh is not executable in %s\n' "$repo_dir" >&2; exit 1; }
mkdir -p -- "$evidence_dir"
evidence_dir="$(realpath -e -- "$evidence_dir")"

run_and_record() {
  local name="$1"
  shift
  printf '==> %s\n' "$name"
  "$@" > >(tee "$evidence_dir/$name.log") 2>&1
}

{
  printf 'repo=%s\n' "$repo_dir"
  printf 'evidence_dir=%s\n' "$evidence_dir"
  printf '%s\n' 'mode=guest-only; no package install or ISO download'
} > "$evidence_dir/metadata.txt"

run_and_record plan "$repo_dir/bootstrap.sh" plan
run_and_record doctor "$repo_dir/bootstrap.sh" doctor
run_and_record bootstrap-dry-run "$repo_dir/bootstrap.sh" bootstrap --dry-run
printf 'Acceptance evidence saved to: %s\n' "$evidence_dir"
