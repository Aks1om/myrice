#!/usr/bin/env python3
"""Generate Quickshell and SwayNC theme outputs from tokens.json."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TOKENS_PATH = REPO_ROOT / ".config/quickshell/theme/tokens.json"
QML_PATH = REPO_ROOT / ".config/quickshell/theme/Colors.qml"
METRICS_QML_PATH = REPO_ROOT / ".config/quickshell/theme/Metrics.qml"
CSS_PATH = REPO_ROOT / ".config/swaync/theme.css"
REQUIRED_SECTIONS = ("colors", "fonts", "fontSizes", "spacing", "radii", "margins", "metrics", "swaync")


def load_tokens() -> dict[str, dict[str, str | int]]:
    try:
        tokens = json.loads(TOKENS_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Cannot read valid JSON from {TOKENS_PATH}: {error}") from error

    if not isinstance(tokens, dict):
        raise SystemExit("Theme tokens must be a JSON object.")
    for section in REQUIRED_SECTIONS:
        if not isinstance(tokens.get(section), dict):
            raise SystemExit(f"Theme tokens require an object section: {section}")
    for name, value in tokens["colors"].items():
        if not isinstance(value, str) or not (value.startswith("#") and len(value) == 7):
            raise SystemExit(f"Color {name} must be a #rrggbb string.")
    for name, value in tokens["metrics"].items():
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            raise SystemExit(f"Metric {name} must be a number.")
        if name != "popupAnchorOffset" and value <= 0:
            raise SystemExit(f"Metric {name} must be positive.")
    if tokens["metrics"].get("density") != 1:
        raise SystemExit("Metric density must be the static design density 1, not monitor scale.")
    return tokens


def qml_properties(tokens: dict[str, dict[str, str | int]], section: str, qml_type: str) -> list[str]:
    return [f"  readonly property {qml_type} {name}: {json.dumps(value)}" for name, value in tokens[section].items()]


def render_qml(tokens: dict[str, dict[str, str | int]]) -> str:
    lines = [
        "// GENERATED FILE — DO NOT EDIT.",
        "// Source: .config/quickshell/theme/tokens.json",
        "pragma Singleton",
        "import QtQuick",
        "",
        "QtObject {",
    ]
    for label, section, qml_type in (
        ("Colors", "colors", "color"),
        ("Fonts", "fonts", "string"),
        ("Font sizes", "fontSizes", "int"),
        ("Spacing", "spacing", "int"),
        ("Radii", "radii", "int"),
        ("Margins", "margins", "int"),
    ):
        lines.extend((f"  // {label}", *qml_properties(tokens, section, qml_type), ""))
    lines.extend(("}", ""))
    return "\n".join(lines)


def render_metrics_qml(tokens: dict[str, dict[str, str | int]]) -> str:
    metrics = tokens["metrics"]
    lines = [
        "// GENERATED FILE — DO NOT EDIT.",
        "// Source: .config/quickshell/theme/tokens.json",
        "pragma Singleton",
        "import QtQuick",
        "",
        "QtObject {",
        "  // Static design density, intentionally independent of monitor scale.",
        f"  readonly property real density: {json.dumps(metrics['density'])}",
        "  function px(value) { return Math.round(value * density) }",
        "",
        "  // Semantic dimensions",
    ]
    for name, value in metrics.items():
        if name != "density":
            lines.append(f"  readonly property int {name}: px({json.dumps(value)})")
    lines.extend(("}", ""))
    return "\n".join(lines)


def rgb(hex_color: str) -> str:
    return ", ".join(str(int(hex_color[index:index + 2], 16)) for index in (1, 3, 5))


def render_css(tokens: dict[str, dict[str, str | int]]) -> str:
    colors = tokens["colors"]
    radii = tokens["radii"]
    swaync = tokens["swaync"]
    return f"""/* GENERATED FILE — DO NOT EDIT. */
/* Source: .config/quickshell/theme/tokens.json */
:root {{
  --swaync-bg-deep: {colors['bgDeep']};
  --swaync-bg-base: {colors['bgBase']};
  --swaync-surface: {colors['surface']};
  --swaync-overlay: {colors['overlay']};
  --swaync-hover: {colors['hover']};
  --swaync-border: {colors['border']};
  --swaync-text: {colors['textPrim']};
  --swaync-text-muted: {colors['textMuted']};
  --swaync-accent: {colors['accent']};
  --swaync-accent-dim: {colors['accentDim']};
  --swaync-radius-sm: {radii['radiusSm']}px;
  --swaync-radius-md: {radii['radiusMd']}px;
  --swaync-radius-lg: {radii['radiusLg']}px;
  --swaync-radius-xl: {radii['radiusXl']}px;

  --cc-bg: var(--swaync-bg-base);
  --noti-border-color: var(--swaync-border);
  --noti-bg: {rgb(colors['surface'])};
  --noti-bg-alpha: 1;
  --noti-bg-darker: var(--swaync-surface);
  --noti-bg-hover: var(--swaync-hover);
  --noti-bg-focus: var(--swaync-overlay);
  --noti-close-bg: var(--swaync-overlay);
  --noti-close-bg-hover: var(--swaync-border);
  --text-color: var(--swaync-text);
  --text-color-disabled: var(--swaync-text-muted);
  --bg-selected: var(--swaync-accent);
  --notification-icon-size: {swaync['notificationIconSize']}px;
  --notification-app-icon-size: {swaync['notificationAppIconSize']}px;
  --border-radius: var(--swaync-radius-lg);
  --font-size-body: {swaync['fontSizeBody']}px;
  --font-size-summary: {swaync['fontSizeSummary']}px;
}}
"""


def update_file(path: Path, content: str, check: bool) -> bool:
    current = path.read_text(encoding="utf-8") if path.exists() else None
    if current == content:
        return False
    if check:
        print(f"Out of date: {path.relative_to(REPO_ROOT)}", file=sys.stderr)
        return True
    path.write_text(content, encoding="utf-8")
    print(f"Generated {path.relative_to(REPO_ROOT)}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if generated files are stale")
    args = parser.parse_args()
    tokens = load_tokens()
    changed = update_file(QML_PATH, render_qml(tokens), args.check)
    changed = update_file(METRICS_QML_PATH, render_metrics_qml(tokens), args.check) or changed
    changed = update_file(CSS_PATH, render_css(tokens), args.check) or changed
    return 1 if args.check and changed else 0


if __name__ == "__main__":
    raise SystemExit(main())
