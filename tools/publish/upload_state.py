"""Which artifacts a store has already accepted.

APKPure serialises uploads behind a manual review: only one version can be in
flight at a time, and the version table does not show a version until review
clears. So a multi-APK release cannot be one long run -- it is many short runs,
and each needs to know what the previous ones achieved.

This records that, keyed by content hash rather than filename, so a rebuilt APK
with the same name is correctly treated as a different artifact.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1


@dataclass
class UploadState:
    path: Path
    target: str
    package_id: str
    accepted: dict[str, dict[str, Any]] = field(default_factory=dict)

    @classmethod
    def load(cls, directory: Path, target: str, package_id: str) -> "UploadState":
        safe = "".join(c if c.isalnum() or c in "-._" else "-" for c in f"{target}-{package_id}")
        path = (directory / f"{safe}.json").expanduser()
        accepted: dict[str, dict[str, Any]] = {}
        if path.is_file():
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                if data.get("schemaVersion") == SCHEMA_VERSION:
                    accepted = data.get("accepted") or {}
            except (json.JSONDecodeError, AttributeError):
                # A corrupt state file must not block a release: the console is
                # the source of truth, and re-checking there is cheap.
                accepted = {}
        return cls(path=path, target=target, package_id=package_id, accepted=accepted)

    def is_accepted(self, sha256: str) -> bool:
        return sha256 in self.accepted

    def record(self, sha256: str, filename: str, version: str, state: str) -> None:
        self.accepted[sha256] = {"filename": filename, "version": version, "state": state}
        self.save()

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "schemaVersion": SCHEMA_VERSION,
            "target": self.target,
            "packageId": self.package_id,
            "accepted": self.accepted,
        }
        self.path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def pending(self, artifacts) -> list:
        return [a for a in artifacts if not self.is_accepted(a.sha256)]
