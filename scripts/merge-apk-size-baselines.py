#!/usr/bin/env python3
"""Merge partial APK size measurements into the committed complete baseline."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import tempfile

HEADER = """# APK size guardrail baselines.
#
# Columns:
# component: CI build component that produced the APK.
# artifact: APK file name produced by Flutter.
# baseline_bytes: approved baseline size in bytes.
# budget_mb: absolute artifact budget in MiB.
#
# This file is updated automatically after successful main builds.
component\tartifact\tbaseline_bytes\tbudget_mb
"""

BaselineKey = tuple[str, str]
BaselineRow = tuple[str, str, int, str]


def _read_rows(path: Path) -> list[BaselineRow]:
    rows: list[BaselineRow] = []
    for line_number, raw_line in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("component\t"):
            continue
        columns = line.split("\t")
        if len(columns) != 4:
            raise ValueError(
                f"{path}:{line_number}: expected 4 tab-separated columns"
            )
        component, artifact, raw_bytes, budget_mb = columns
        if not component or not artifact:
            raise ValueError(
                f"{path}:{line_number}: component and artifact are required"
            )
        try:
            baseline_bytes = int(raw_bytes)
            budget = float(budget_mb)
        except ValueError as error:
            raise ValueError(
                f"{path}:{line_number}: bytes and budget must be numeric"
            ) from error
        if baseline_bytes <= 0 or budget <= 0:
            raise ValueError(
                f"{path}:{line_number}: bytes and budget must be positive"
            )
        rows.append((component, artifact, baseline_bytes, budget_mb))
    return rows


def merge_baselines(
    baseline: Path,
    updates_dir: Path,
) -> dict[BaselineKey, BaselineRow]:
    if not baseline.is_file():
        raise ValueError(f"baseline file not found: {baseline}")
    if not updates_dir.is_dir():
        raise ValueError(f"updates directory not found: {updates_dir}")

    update_files = sorted(updates_dir.glob("*.tsv"))
    if not update_files:
        raise ValueError(f"no baseline update files found in: {updates_dir}")

    merged: dict[BaselineKey, BaselineRow] = {}
    for row in _read_rows(baseline):
        key = (row[0], row[1])
        if key in merged:
            raise ValueError(f"{baseline}: duplicate baseline key: {key}")
        merged[key] = row

    update_keys: set[BaselineKey] = set()
    for update_file in update_files:
        for row in _read_rows(update_file):
            key = (row[0], row[1])
            if key in update_keys:
                raise ValueError(f"{update_file}: duplicate update key: {key}")
            update_keys.add(key)
            merged[key] = row

    return merged


def write_baselines(
    output: Path,
    rows: dict[BaselineKey, BaselineRow],
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=output.parent,
        prefix=f".{output.name}.",
        delete=False,
    ) as temporary:
        temporary.write(HEADER)
        for key in sorted(rows):
            component, artifact, baseline_bytes, budget_mb = rows[key]
            temporary.write(
                f"{component}\t{artifact}\t{baseline_bytes}\t{budget_mb}\n"
            )
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--updates-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    try:
        rows = merge_baselines(args.baseline, args.updates_dir)
        write_baselines(args.output, rows)
    except ValueError as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
