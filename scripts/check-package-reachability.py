#!/usr/bin/env python3
"""Fail CI when a package/*/ has drifted out of every app flavor's dependency
graph without declaring why (#1681).

Proves WIRING, not liveness: a package can be imported by dead code and
still pass this gate (see the periodic dead-provider report for that,
report-only by design — this check cannot express "used", only "reachable").

Algorithm:
  1. Read every app/pubspec*.yaml's direct path dependencies as roots.
  2. BFS the path-dependency graph across packages/*/pubspec.yaml.
  3. Any packages/*/module.yaml package NOT in that closure must declare a
     non-active `status:` (pre-wired | tool-only | template) — see
     docs/agents/COUNCIL.md's manifest schema. No status field on an
     unreachable package is the failure this gate exists to catch.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGES_DIR = ROOT / "packages"
APP_DIR = ROOT / "app"
NON_ACTIVE_STATUSES = {"pre-wired", "tool-only", "template"}


def parse_pubspec_name(text):
    match = re.search(r"^name:\s*(\S+)\s*$", text, re.MULTILINE)
    return match.group(1) if match else None


def parse_pubspec_path_deps(text):
    """Local path-dependency package names from a top-level `dependencies:` block."""
    lines = text.splitlines()
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


def parse_module_status(text):
    match = re.search(r"^status:\s*(\S+)", text, re.MULTILINE)
    return match.group(1) if match else None


def build_package_graph():
    """package name -> set of local path-dependency package names."""
    graph = {}
    for pubspec_path in sorted(PACKAGES_DIR.glob("*/pubspec.yaml")):
        text = pubspec_path.read_text(encoding="utf-8")
        name = parse_pubspec_name(text)
        if name is None:
            continue
        graph[name] = parse_pubspec_path_deps(text)
    return graph


def roots_from_app_flavors():
    """Direct path deps of every app/pubspec*.yaml — the flavor roots."""
    roots = set()
    flavor_files = sorted(APP_DIR.glob("pubspec*.yaml"))
    if not flavor_files:
        raise SystemExit("no app/pubspec*.yaml files found — cannot compute reachability")
    for flavor_path in flavor_files:
        text = flavor_path.read_text(encoding="utf-8")
        roots |= parse_pubspec_path_deps(text)
    return roots, flavor_files


def transitive_closure(roots, graph):
    seen = set()
    frontier = list(roots)
    while frontier:
        pkg = frontier.pop()
        if pkg in seen:
            continue
        seen.add(pkg)
        for dep in graph.get(pkg, ()):
            if dep not in seen:
                frontier.append(dep)
    return seen


def main():
    graph = build_package_graph()
    roots, flavor_files = roots_from_app_flavors()
    reachable = transitive_closure(roots, graph)

    manifests = sorted(PACKAGES_DIR.glob("*/module.yaml"))
    if not manifests:
        print("no module.yaml manifests found, nothing to check")
        return 0

    failed = False
    declared_seams = 0
    for manifest_path in manifests:
        package_dir = manifest_path.parent
        name = package_dir.name
        if name in reachable:
            continue
        status = parse_module_status(manifest_path.read_text(encoding="utf-8"))
        if status in NON_ACTIVE_STATUSES:
            declared_seams += 1
            continue
        failed = True
        print(
            f"::error file={manifest_path.relative_to(ROOT)}::"
            f"'{name}' is unreachable from every app flavor "
            f"({', '.join(f.name for f in flavor_files)}) and has no "
            f"status: pre-wired|tool-only|template declared. Either wire it "
            f"in, archive it, or declare why it's intentionally unreached "
            f"(docs/agents/COUNCIL.md manifest schema)."
        )

    if failed:
        return 1

    print(
        f"{len(manifests)} package(s) checked: "
        f"{len(manifests) - declared_seams} reachable, "
        f"{declared_seams} declared as an intentional non-active seam"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
