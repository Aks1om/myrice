#!/usr/bin/env python3
"""Generate safe bootstrap environment reports, locks, and rollback state."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path


REPO_DIR = Path(__file__).resolve().parent.parent
PACKAGE_MANIFESTS = ("pacman.txt", "aur.txt", "lts-kernel.txt", "nvidia.txt")
MANAGED_PATHS = {
    "dotfiles": ["$HOME/.config/*", "$HOME/.local/bin/*", "$HOME/.local/share/applications/*", "$HOME/.zshrc"],
    "system": ["/etc/*"],
    "services": ["$HOME/.config/systemd/user/*.service"],
    "locale": ["/etc/locale.gen"],
    "lts-kernel": ["/boot/loader/entries/*-lts.conf"],
    "backup": ["/etc/timeshift/timeshift.json", "/etc/pacman.d/hooks/50-timeshift.hook"],
    "wifi-fix": ["/etc/modprobe.d/blacklist-rtw88.conf", "/etc/modprobe.d/rtw88.conf", "/etc/modprobe.d/8821ce.conf", "/etc/modprobe.d/cfg80211.conf", "/etc/NetworkManager/conf.d/30-wifi-powersave.conf", "/boot/loader/entries/*.conf"],
    "myrice-hyprland-session": ["/usr/local/bin/myrice-hyprland", "/usr/local/share/wayland-sessions/myrice-hyprland.desktop", "/etc/sddm.conf.d/90-myrice-wayland-sessions.conf"],
}


def timestamp() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def git_commit() -> str | None:
    try:
        return subprocess.check_output(
            ["git", "-C", str(REPO_DIR), "rev-parse", "HEAD"], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def profile_name(path: Path) -> str:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read profile {path}: {exc}") from exc
    name = data.get("name")
    if not isinstance(name, str) or not name:
        raise ValueError(f"profile {path} has no valid name")
    return name


def manifest_hashes() -> dict[str, str]:
    hashes: dict[str, str] = {}
    for name in PACKAGE_MANIFESTS:
        path = REPO_DIR / "packages" / name
        if path.is_file():
            hashes[f"packages/{name}"] = hashlib.sha256(path.read_bytes()).hexdigest()
    return hashes


def state_dir() -> Path:
    root = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    return root / "myrice"


def managed_paths(stages: list[str]) -> list[str]:
    return sorted({path for stage in stages for path in MANAGED_PATHS.get(stage, [])})


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def state_command(args: argparse.Namespace) -> int:
    data = {
        "format_version": 1,
        "status": args.status,
        "generated_at": timestamp(),
        "repository_commit": git_commit(),
        "profiles": args.profile or ["direct-install"],
        "stages": args.stage,
        "managed_paths": managed_paths(args.stage),
    }
    target = state_dir() / f"{args.status}.json"
    write_json(target, data)
    print(target)
    return 0


def lock_command(args: argparse.Namespace) -> int:
    try:
        profiles = [profile_name(Path(path)) for path in args.profiles]
    except ValueError as exc:
        print(f"lock error: {exc}", file=sys.stderr)
        return 2
    data = {
        "format_version": 1,
        "generated_at": timestamp(),
        "repository_commit": git_commit(),
        "package_manifest_sha256": manifest_hashes(),
        "profiles": profiles,
    }
    target = Path(args.output) if args.output else state_dir() / "bootstrap-lock.json"
    write_json(target, data)
    print(target)
    return 0


def command_output(command: list[str]) -> str | None:
    try:
        return subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def doctor_report() -> dict:
    checks: list[dict[str, object]] = []

    def add(name: str, status: str, detail: str) -> None:
        checks.append({"check": name, "status": status, "detail": detail})

    missing_required = [tool for tool in ("bash", "python3", "git") if not shutil.which(tool)]
    add(
        "bootstrap_commands",
        "FAIL" if missing_required else "PASS",
        "missing required bootstrap commands: " + ", ".join(missing_required) if missing_required else "bash, python3, and git are available",
    )

    lspci = shutil.which("lspci")
    if not lspci:
        add("gpu_pci", "WARN", "lspci is unavailable; PCI GPU inventory was not read")
    else:
        output = command_output([lspci, "-nn"])
        devices = [line for line in (output or "").splitlines() if any(kind in line.lower() for kind in ("vga compatible controller", "3d controller", "display controller"))]
        if devices:
            add("gpu_pci", "PASS", "; ".join(devices))
        else:
            add("gpu_pci", "WARN", "no VGA, 3D, or display PCI controller was reported")

    add("nvidia_smi", "PASS" if shutil.which("nvidia-smi") else "WARN", "nvidia-smi is available" if shutil.which("nvidia-smi") else "nvidia-smi is not installed or not on PATH")
    for parameter in ("modeset", "fbdev"):
        path = Path("/sys/module/nvidia_drm/parameters") / parameter
        if not path.exists():
            add(f"nvidia_drm_{parameter}", "WARN", "nvidia_drm parameter is unavailable")
            continue
        value = path.read_text(encoding="utf-8").strip()
        add(f"nvidia_drm_{parameter}", "PASS" if value in {"Y", "1"} else "WARN", f"nvidia_drm.{parameter}={value}")

    add("prime_run", "PASS" if shutil.which("prime-run") else "WARN", "prime-run is available" if shutil.which("prime-run") else "prime-run is unavailable")
    pacman = shutil.which("pacman")
    egl_present = bool(pacman and command_output([pacman, "-Q", "egl-wayland"])) or bool(
        list(Path("/usr/lib").glob("libnvidia-egl-wayland.so*"))
    )
    wayland = os.environ.get("XDG_SESSION_TYPE") == "wayland"
    if egl_present and wayland:
        add("egl_wayland", "PASS", "egl-wayland is installed and a Wayland session is detected")
    elif egl_present:
        add("egl_wayland", "WARN", "egl-wayland is installed; no active Wayland session detected")
    else:
        add("egl_wayland", "WARN", "egl-wayland was not detected")
    add("nvidia_profile_policy", "PASS", "the NVIDIA profile is opt-in and is never auto-detected or auto-applied")
    return {"format_version": 1, "generated_at": timestamp(), "checks": checks}


def doctor_command(args: argparse.Namespace) -> int:
    report = doctor_report()
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        for check in report["checks"]:
            print(f"{check['status']}: {check['check']}: {check['detail']}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    lock = subparsers.add_parser("lock")
    lock.add_argument("profiles", nargs="+", help="resolved profile JSON files")
    lock.add_argument("--output")
    lock.set_defaults(func=lock_command)
    state = subparsers.add_parser("state")
    state.add_argument("--status", choices=("planned", "applied"), required=True)
    state.add_argument("--stage", action="append", default=[])
    state.add_argument("--profile", action="append", default=[])
    state.set_defaults(func=state_command)
    doctor = subparsers.add_parser("doctor")
    doctor.add_argument("--json", action="store_true")
    doctor.set_defaults(func=doctor_command)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
