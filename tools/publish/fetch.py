"""Pull release artifacts from a GitHub Release.

Publishing never builds. Every store upload starts from the exact assets that
were attached to a published GitHub Release, so a store and the release page can
never disagree about what shipped.

One release tag can carry several profiles (`Airo-…`, `Airo-TV-…`,
`AiroCoins-…`), each with its own `*-Release-Manifest.json`. This module
downloads once and then resolves the right manifest for the profile you asked
for.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from .errors import ManifestError, PublishError, RemoteError

MANIFEST_GLOB = "*Release-Manifest.json"


@dataclass(frozen=True)
class FetchedRelease:
    tag: str
    directory: Path
    manifests: dict[str, Path]

    def manifest_for(self, profile_id: str | None) -> Path:
        if not self.manifests:
            raise ManifestError(
                f"No {MANIFEST_GLOB} asset found on release {self.tag}. "
                "The release was published without a machine-readable manifest."
            )
        if profile_id:
            if profile_id not in self.manifests:
                raise ManifestError(
                    f"Release {self.tag} has no manifest for profile {profile_id!r}. "
                    f"Available: {', '.join(sorted(self.manifests))}"
                )
            return self.manifests[profile_id]
        if len(self.manifests) > 1:
            raise ManifestError(
                f"Release {self.tag} carries {len(self.manifests)} manifests "
                f"({', '.join(sorted(self.manifests))}). Pass --profile to choose one."
            )
        return next(iter(self.manifests.values()))


def fetch_release(
    tag: str,
    destination: Path,
    repository: str = "DevelopersCoffee/airo",
    clean: bool = False,
) -> FetchedRelease:
    """Download every asset of `tag` into `destination` and index the manifests."""
    if shutil.which("gh") is None:
        raise PublishError("The GitHub CLI (`gh`) is required to fetch release assets.")
    if not re.fullmatch(r"[A-Za-z0-9._/-]+", tag):
        raise PublishError(f"Refusing to use an unsafe release tag: {tag!r}")

    destination = destination.expanduser().resolve()
    if clean and destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True, exist_ok=True)

    completed = subprocess.run(
        ["gh", "release", "download", tag, "--repo", repository, "--dir", str(destination), "--clobber"],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise RemoteError(
            f"gh release download {tag} failed: "
            f"{(completed.stderr or completed.stdout).strip()[:1000]}"
        )

    return FetchedRelease(tag=tag, directory=destination, manifests=index_manifests(destination))


def index_manifests(directory: Path) -> dict[str, Path]:
    """Map profile id -> the most complete manifest covering that profile.

    A release tag can carry both a per-leg manifest (`Airo-TV-…`) and a combined
    orchestrator manifest (`Airo-…`) that covers several profiles. Both are
    valid; the one describing more of the profile's artifacts is the one to
    publish from, because a manifest that omits an artifact silently omits it
    from the store upload too. Ties break on filename so the choice is stable.
    """
    coverage: dict[str, list[tuple[int, str, Path]]] = {}
    for path in sorted(directory.glob(MANIFEST_GLOB)):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            entries = data.get("artifacts") or []
        except (json.JSONDecodeError, AttributeError, TypeError):
            continue
        if not isinstance(entries, list):
            continue
        counts: dict[str, int] = {}
        for entry in entries:
            if isinstance(entry, dict) and entry.get("profileId"):
                profile_id = str(entry["profileId"])
                counts[profile_id] = counts.get(profile_id, 0) + 1
        for profile_id, count in counts.items():
            coverage.setdefault(profile_id, []).append((count, path.name, path))

    return {
        profile_id: max(candidates, key=lambda item: (item[0], item[1]))[2]
        for profile_id, candidates in coverage.items()
    }
