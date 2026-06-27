#!/usr/bin/env python3
"""Validate or update Airo plugin kill-switch config JSON.

Examples:
  scripts/plugin_kill_switch_admin.py validate config/plugin-kill-switch.json
  scripts/plugin_kill_switch_admin.py disable config/plugin-kill-switch.json com.airo.plugin.games \
    --message "Games temporarily unavailable" --max-version 1.2.3
  scripts/plugin_kill_switch_admin.py enable config/plugin-kill-switch.json com.airo.plugin.games
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def load_config(path: Path) -> dict[str, Any]:
    if not path.exists() or not path.read_text(encoding="utf-8").strip():
        return {"version": now(), "default_enabled": True, "plugins": {}}
    return json.loads(path.read_text(encoding="utf-8"))


def now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def validate(config: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if not isinstance(config.get("version"), str) or not config["version"]:
        errors.append("version must be a non-empty string")
    if not isinstance(config.get("plugins", {}), dict):
        errors.append("plugins must be an object keyed by plugin id")
        return errors
    for plugin_id, rule in config.get("plugins", {}).items():
        if not plugin_id.startswith("com.airo.plugin."):
            errors.append(f"{plugin_id}: plugin id must start with com.airo.plugin.")
        if not isinstance(rule, dict):
            errors.append(f"{plugin_id}: rule must be an object")
            continue
        if not isinstance(rule.get("enabled", True), bool):
            errors.append(f"{plugin_id}: enabled must be boolean")
        for key in ("min_version", "max_version", "message", "disabled_at", "eta_restore", "cohort"):
            if key in rule and rule[key] is not None and not isinstance(rule[key], str):
                errors.append(f"{plugin_id}: {key} must be string or null")
    return errors


def write_config(path: Path, config: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(config, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def command_validate(args: argparse.Namespace) -> int:
    config = load_config(args.path)
    errors = validate(config)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print(f"OK: {args.path}")
    return 0


def command_disable(args: argparse.Namespace) -> int:
    config = load_config(args.path)
    config.setdefault("plugins", {})[args.plugin_id] = {
        "enabled": False,
        "message": args.message,
        "disabled_at": now(),
        **({"min_version": args.min_version} if args.min_version else {}),
        **({"max_version": args.max_version} if args.max_version else {}),
        **({"eta_restore": args.eta_restore} if args.eta_restore else {}),
        **({"cohort": args.cohort} if args.cohort else {}),
    }
    config["version"] = now()
    errors = validate(config)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    write_config(args.path, config)
    print(f"Disabled {args.plugin_id} in {args.path}")
    return 0


def command_enable(args: argparse.Namespace) -> int:
    config = load_config(args.path)
    config.setdefault("plugins", {})[args.plugin_id] = {"enabled": True}
    config["version"] = now()
    errors = validate(config)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    write_config(args.path, config)
    print(f"Enabled {args.plugin_id} in {args.path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    validate_parser = sub.add_parser("validate")
    validate_parser.add_argument("path", type=Path)
    validate_parser.set_defaults(func=command_validate)

    disable = sub.add_parser("disable")
    disable.add_argument("path", type=Path)
    disable.add_argument("plugin_id")
    disable.add_argument("--message", required=True)
    disable.add_argument("--min-version")
    disable.add_argument("--max-version")
    disable.add_argument("--eta-restore")
    disable.add_argument("--cohort")
    disable.set_defaults(func=command_disable)

    enable = sub.add_parser("enable")
    enable.add_argument("path", type=Path)
    enable.add_argument("plugin_id")
    enable.set_defaults(func=command_enable)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
