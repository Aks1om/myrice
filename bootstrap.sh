#!/usr/bin/env bash
# Portable profile-aware entrypoint. It is safe by default: no /etc, /boot,
# drivers, Wi-Fi fixes, SDDM, or hardware-specific stages are selected.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base_profile="$repo_dir/profiles/base.json"
command=plan
dry_run=0
assume_yes=0
non_interactive=0
json_output=0
rollback_plan=0
profiles=()

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [plan|doctor|bootstrap|lock|rollback] [options]

Commands:
  plan                 Print resolved stages and safety boundaries (default).
   doctor               Validate profiles and print a read-only environment report.
   bootstrap            Run the resolved compatible install.sh stages.
   lock                 Write a reproducibility lock under XDG_STATE_HOME/myrice.
   rollback --plan      Show managed paths from the last applied state; never deletes.

Options:
  --profile PATH       Add an explicit profile fragment (repeatable).
  --dry-run            Print install commands; do not apply changes.
   --yes, -y            Pass --yes to install.sh for bootstrap.
   --non-interactive    Pass --non-interactive to install.sh for bootstrap.
   --json               Emit JSON for doctor.
   --plan               Required for rollback; it only prints the rollback plan.
  -h, --help           Show this help.

Base is portable and excludes /etc, /boot, drivers, Wi-Fi fixes, SDDM, and
laptop services. Add only reviewed opt-in fragments, for example:
  ./bootstrap.sh plan --profile profiles/optional/laptop-rtl8821ce.json
EOF
}

resolve_profile_path() {
  local input_path="$1"
  local candidate_path

  if [[ "$input_path" == /* ]]; then
    candidate_path="$input_path"
  else
    candidate_path="$repo_dir/$input_path"
  fi

  profile_path="$(realpath -e -- "$candidate_path")" || {
    printf 'Invalid profile path: %s\n' "$input_path" >&2
    exit 2
  }
  case "$profile_path" in
    "$repo_dir"/*) ;;
    *)
      printf 'Profile path must resolve within the repository: %s\n' "$input_path" >&2
      exit 2
      ;;
  esac
}

if [[ $# -gt 0 && "$1" != --* && "$1" != -h ]]; then
  command="$1"
  shift
fi
case "$command" in plan|doctor|bootstrap|lock|rollback) ;; *) printf 'Unknown command: %s\n' "$command" >&2; usage >&2; exit 2;; esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      shift
      [[ $# -gt 0 ]] || { printf '%s\n' '--profile requires a path' >&2; exit 2; }
      resolve_profile_path "$1"
      profiles+=("$profile_path")
      ;;
    --dry-run) dry_run=1;;
    --yes|-y) assume_yes=1;;
    --non-interactive)
      [[ "$command" == bootstrap ]] || { printf '%s\n' '--non-interactive is valid only with bootstrap' >&2; exit 2; }
      non_interactive=1
      ;;
    --json) json_output=1;;
    --plan) rollback_plan=1;;
    -h|--help) usage; exit 0;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2;;
  esac
  shift
done

resolved="$(python3 "$repo_dir/scripts/profile.py" resolve "$base_profile" "${profiles[@]}")"
stages="$(printf '%s\n' "$resolved" | while IFS= read -r line; do [[ "$line" == stages=* ]] && printf '%s\n' "${line#stages=}"; done || true)"
capabilities="$(printf '%s\n' "$resolved" | while IFS= read -r line; do [[ "$line" == capabilities=* ]] && printf '%s\n' "${line#capabilities=}"; done || true)"
optional_commands="$(printf '%s\n' "$resolved" | while IFS= read -r line; do [[ "$line" == optional_commands=* ]] && printf '%s\n' "${line#optional_commands=}"; done || true)"
profile_names=(base)
for profile in "${profiles[@]}"; do
  profile_names+=("$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["name"])' "$profile")")
done

print_plan() {
  printf 'Profiles: base'
  for profile in "${profiles[@]}"; do printf ', %s' "$profile"; done
  printf '\n'
  printf 'Enabled stages: %s\n' "$stages"
  printf 'Enabled capabilities: %s\n' "${capabilities:-none}"
  if [[ ${#profiles[@]} -eq 0 ]]; then
    printf '%s\n' 'Base safety: no /etc, /boot, drivers, Wi-Fi fixes, SDDM, or laptop services are enabled.'
  else
    printf '%s\n' 'Explicit profile selected: review enabled hardware and system stages/capabilities before bootstrap.'
  fi
}

case "$command" in
  plan) print_plan;;
  doctor)
    [[ $json_output -eq 0 ]] && print_plan
    if [[ $json_output -eq 1 ]]; then
      python3 "$repo_dir/scripts/environment.py" doctor --json
      exit 0
    fi
    python3 "$repo_dir/scripts/profile.py" validate "$base_profile" "${profiles[@]}"
    IFS=, read -r -a optional_tools <<< "$optional_commands"
    for tool in "${optional_tools[@]}"; do
      [[ -z "$tool" ]] || command -v "$tool" >/dev/null 2>&1 || printf 'warning: optional personal command missing: %s\n' "$tool" >&2
    done
    python3 "$repo_dir/scripts/environment.py" doctor
    ;;
  lock)
    python3 "$repo_dir/scripts/environment.py" lock "$base_profile" "${profiles[@]}"
    ;;
  rollback)
    [[ $rollback_plan -eq 1 ]] || { printf '%s\n' 'rollback is plan-only; use ./bootstrap.sh rollback --plan' >&2; exit 2; }
    state_file="${XDG_STATE_HOME:-$HOME/.local/state}/myrice/applied.json"
    if [[ ! -f "$state_file" ]]; then
      printf 'No applied rollback state found: %s\n' "$state_file"
      exit 0
    fi
    printf '%s\n' 'Rollback plan only; no paths will be changed or removed.'
    python3 -c 'import json, sys; [print(path) for path in json.load(open(sys.argv[1], encoding="utf-8")).get("managed_paths", [])]' "$state_file"
    ;;
  bootstrap)
    IFS=, read -r -a stage_list <<< "$stages"
    install_args=()
    for stage in "${stage_list[@]}"; do install_args+=(--stage "$stage"); done
    [[ $dry_run -eq 1 ]] && install_args+=(--dry-run)
    [[ $assume_yes -eq 1 ]] && install_args+=(--yes)
    [[ $non_interactive -eq 1 ]] && install_args+=(--non-interactive)
    for name in "${profile_names[@]}"; do install_args+=(--state-profile "$name"); done
    if [[ $dry_run -eq 0 ]]; then
      state_args=(state --status planned)
      for stage in "${stage_list[@]}"; do state_args+=(--stage "$stage"); done
      for name in "${profile_names[@]}"; do state_args+=(--profile "$name"); done
      python3 "$repo_dir/scripts/environment.py" "${state_args[@]}" >/dev/null
    fi
    if "$repo_dir/install.sh" "${install_args[@]}"; then
      :
    else
      status=$?
      exit "$status"
    fi
    ;;
esac
