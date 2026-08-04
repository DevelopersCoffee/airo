"""Audit evidence for every publish attempt.

A store upload is an outward-facing, hard-to-reverse action. Each attempt writes
a timestamped directory holding the resolved plan, the console log, and any
screenshots or page dumps a browser-driven publisher captured, so a release can
be reconstructed after the fact without re-opening the store console.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class EvidenceRecorder:
    """Writes logs and files under one publish attempt's evidence directory."""

    root: Path
    quiet: bool = False

    def __post_init__(self) -> None:
        self.root = self.root.expanduser().resolve()
        self.root.mkdir(parents=True, exist_ok=True)
        self._log_path = self.root / "publish.log"
        self._written: list[Path] = []

    @classmethod
    def for_attempt(
        cls, base_dir: Path, target: str, profile_id: str, version: str, quiet: bool = False
    ) -> "EvidenceRecorder":
        safe = lambda value: "".join(c if c.isalnum() or c in "-._" else "-" for c in value)
        return cls(root=base_dir / safe(target) / safe(profile_id) / safe(version), quiet=quiet)

    def log(self, message: str, level: str = "info") -> None:
        line = f"[{level}] {message}"
        with self._log_path.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")
        if not self.quiet:
            stream = sys.stderr if level in {"warn", "error"} else sys.stdout
            print(line, file=stream, flush=True)

    def warn(self, message: str) -> None:
        self.log(message, level="warn")

    def error(self, message: str) -> None:
        self.log(message, level="error")

    def write_json(self, name: str, payload: Any) -> Path:
        path = self.root / name
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        self._written.append(path)
        return path

    def write_text(self, name: str, content: str) -> Path:
        path = self.root / name
        path.write_text(content, encoding="utf-8")
        self._written.append(path)
        return path

    def write_bytes(self, name: str, content: bytes) -> Path:
        path = self.root / name
        path.write_bytes(content)
        self._written.append(path)
        return path

    def file_path(self, name: str) -> Path:
        """Reserve a path a third-party tool (Playwright, gh) will write to."""
        path = self.root / name
        self._written.append(path)
        return path

    def artifacts(self) -> list[str]:
        seen: list[str] = []
        for path in [self._log_path, *self._written]:
            if path.exists():
                text = str(path)
                if text not in seen:
                    seen.append(text)
        return seen
