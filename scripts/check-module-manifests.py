#!/usr/bin/env python3
"""Validate packages/*/module.yaml against pubspec.yaml and the council role registry.

Checks, per manifest:
  1. `name` matches the package's pubspec.yaml `name`.
  2. `owner` (and each `reviewers` entry) is a known council role.
  3. `allowed_dependencies` is a superset of the package's real local
     path-dependency names (from pubspec.yaml `dependencies:`).
  4. No entry in `forbidden_dependencies` is actually depended on.

Does not check whether the *assigned* owner is the *correct* owner for a
package's contents — that is a judgment call for council role review, not a
mechanical check. See docs/agents/COUNCIL.md.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGES_DIR = ROOT / "packages"
ROLES_FILE = ROOT / ".github" / "council-roles.json"


def error(message, path=None):
    if path:
        print(f"::error file={path}::{message}")
    else:
        print(f"::error::{message}")


def load_valid_roles():
    data = json.loads(ROLES_FILE.read_text(encoding="utf-8"))
    return set(data["roles"])


def parse_pubspec_name(pubspec_text):
    match = re.search(r"^name:\s*(\S+)\s*$", pubspec_text, re.MULTILINE)
    return match.group(1) if match else None


def parse_pubspec_path_deps(pubspec_text):
    """Return local path-dependency package names from a `dependencies:` block."""
    lines = pubspec_text.splitlines()
    deps = set()
    in_deps = False
    current = None
    for raw in lines:
        if re.match(r"^dependencies:\s*$", raw):
            in_deps = True
            current = None
            continue
        if in_deps and raw and not raw.startswith(" "):
            break
        if not in_deps:
            continue
        top_key = re.match(r"^  (\S+):\s*$", raw)
        if top_key:
            current = top_key.group(1)
            continue
        if current and re.match(r"^    path:\s*", raw):
            deps.add(current)
    return deps


def parse_module_yaml(text):
    """Minimal parser for the fixed module.yaml schema (scalars, flat lists, empty {}/[])."""
    result = {
        "name": None,
        "owner": None,
        "reviewers": [],
        "contracts": [],
        "allowed_dependencies": [],
        "forbidden_dependencies": [],
    }
    lines = text.splitlines()
    current_list_key = None
    for raw in lines:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        list_item = re.match(r"^  - (.+)$", raw)
        if list_item and current_list_key:
            result[current_list_key].append(list_item.group(1).strip())
            continue
        top = re.match(r"^(\w+):\s*(.*)$", raw)
        if not top:
            continue
        key, value = top.group(1), top.group(2).strip()
        if key in ("name", "owner"):
            result[key] = value
            current_list_key = None
        elif key in ("reviewers", "contracts", "allowed_dependencies", "forbidden_dependencies"):
            current_list_key = key if value == "" else None
            if value not in ("", "[]"):
                error(f"unexpected inline value for {key}: {value!r}")
        else:
            current_list_key = None
    return result


def check_manifest(package_dir, valid_roles):
    problems = []
    manifest_path = package_dir / "module.yaml"
    pubspec_path = package_dir / "pubspec.yaml"

    manifest = parse_module_yaml(manifest_path.read_text(encoding="utf-8"))
    pubspec_text = pubspec_path.read_text(encoding="utf-8")
    pubspec_name = parse_pubspec_name(pubspec_text)
    path_deps = parse_pubspec_path_deps(pubspec_text)

    if manifest["name"] != pubspec_name:
        problems.append(
            f"module.yaml name '{manifest['name']}' does not match pubspec.yaml name '{pubspec_name}'"
        )

    if manifest["owner"] not in valid_roles:
        problems.append(f"owner '{manifest['owner']}' is not a known council role")

    for reviewer in manifest["reviewers"]:
        if reviewer not in valid_roles:
            problems.append(f"reviewer '{reviewer}' is not a known council role")

    missing_allowed = path_deps - set(manifest["allowed_dependencies"])
    if missing_allowed:
        problems.append(
            "allowed_dependencies is missing real path dependencies: "
            + ", ".join(sorted(missing_allowed))
        )

    forbidden_but_present = set(manifest["forbidden_dependencies"]) & path_deps
    if forbidden_but_present:
        problems.append(
            "forbidden_dependencies are actually depended on: "
            + ", ".join(sorted(forbidden_but_present))
        )

    return problems


def main():
    valid_roles = load_valid_roles()
    manifests = sorted(PACKAGES_DIR.glob("*/module.yaml"))

    if not manifests:
        print("no module.yaml manifests found, nothing to check")
        return 0

    failed = False
    for manifest_path in manifests:
        package_dir = manifest_path.parent
        problems = check_manifest(package_dir, valid_roles)
        if problems:
            failed = True
            for problem in problems:
                error(problem, path=str(manifest_path.relative_to(ROOT)))
        else:
            print(f"ok: {manifest_path.relative_to(ROOT)}")

    if failed:
        return 1

    print(f"{len(manifests)} module.yaml manifest(s) valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
