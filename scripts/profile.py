#!/usr/bin/env python3
"""Validate and resolve small declarative bootstrap profile fragments."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

STAGES = {
    "preflight", "pacman", "aur", "dotfiles", "system", "services", "locale",
    "lts-kernel", "backup", "wifi-fix", "sddm", "myrice-hyprland-session",
    "nvidia", "nvidia-prime",
}
CAPABILITIES = {
    "system", "backup", "lts-kernel", "laptop_services", "rtl8821ce_wifi",
    "sddm_session", "nvidia_graphics",
}
STAGE_CAPABILITIES = {
    "system": "system",
    "locale": "system",
    "services": "laptop_services",
    "lts-kernel": "lts-kernel",
    "backup": "backup",
    "wifi-fix": "rtl8821ce_wifi",
    "sddm": "sddm_session",
    "myrice-hyprland-session": "sddm_session",
    "nvidia": "nvidia_graphics",
    "nvidia-prime": "nvidia_graphics",
}


def load_profile(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"{path}: profile must be a JSON object")
    validate_profile(data, path)
    return data


def validate_profile(data: dict, path: Path) -> None:
    if data.get("version") != 1:
        raise ValueError(f"{path}: version must be 1")
    if not isinstance(data.get("name"), str) or not data["name"]:
        raise ValueError(f"{path}: name must be a non-empty string")
    for key in ("stages", "optional_commands"):
        value = data.get(key, [])
        if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
            raise ValueError(f"{path}: {key} must be an array of strings")
    unknown_stages = set(data.get("stages", [])) - STAGES
    if unknown_stages:
        raise ValueError(f"{path}: unknown stages: {', '.join(sorted(unknown_stages))}")
    capabilities = data.get("capabilities", {})
    if not isinstance(capabilities, dict):
        raise ValueError(f"{path}: capabilities must be an object")
    unknown_capabilities = set(capabilities) - CAPABILITIES
    if unknown_capabilities:
        raise ValueError(f"{path}: unknown capabilities: {', '.join(sorted(unknown_capabilities))}")
    if not all(isinstance(value, bool) for value in capabilities.values()):
        raise ValueError(f"{path}: capability values must be booleans")
    for stage in data.get("stages", []):
        capability = STAGE_CAPABILITIES.get(stage)
        if capability and capabilities.get(capability) is not True:
            raise ValueError(
                f"{path}: stage {stage!r} requires capability {capability!r} to be true"
            )


def resolve(paths: list[Path]) -> tuple[list[str], dict[str, bool], list[str]]:
    stages: list[str] = []
    capabilities = {name: False for name in CAPABILITIES}
    optional_commands: list[str] = []
    for path in paths:
        profile = load_profile(path)
        for stage in profile.get("stages", []):
            if stage not in stages:
                stages.append(stage)
        capabilities.update(profile.get("capabilities", {}))
        for command in profile.get("optional_commands", []):
            if command not in optional_commands:
                optional_commands.append(command)
    for stage in stages:
        capability = STAGE_CAPABILITIES.get(stage)
        if capability and not capabilities[capability]:
            raise ValueError(
                f"resolved profiles: stage {stage!r} requires capability {capability!r} to be true"
            )
    return stages, capabilities, optional_commands


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "resolve"))
    parser.add_argument("profiles", nargs="+", type=Path)
    args = parser.parse_args()
    try:
        stages, capabilities, optional_commands = resolve(args.profiles)
        if args.command == "validate":
            for path in args.profiles:
                print(f"valid: {path}")
            return 0
        print("stages=" + ",".join(stages))
        print("capabilities=" + ",".join(name for name, enabled in sorted(capabilities.items()) if enabled))
        print("optional_commands=" + ",".join(optional_commands))
    except ValueError as exc:
        print(f"profile error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
