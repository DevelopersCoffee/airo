"""Typed release metadata shared by every store publisher.

The single source of truth is the release manifest already produced by
``scripts/generate-release-manifest.py``. Publishers never re-derive version,
package id, ABI, or checksum information: they read it from here so a store
upload can only ever describe the exact bytes that were built and hashed.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Iterable

from .errors import ArtifactIntegrityError, ManifestError

SUPPORTED_SCHEMA_VERSIONS = frozenset({1})

_CHUNK = 1024 * 1024


def _require(entry: dict[str, Any], key: str, context: str) -> Any:
    if key not in entry:
        raise ManifestError(f"{context} is missing required field '{key}'")
    return entry[key]


@dataclass(frozen=True)
class Artifact:
    """One built file plus everything a store needs to describe it."""

    filename: str
    profile_id: str
    package_id: str
    version: str
    build_number: str
    artifact_type: str
    abi: str
    distribution_channel: str
    size_bytes: int
    sha256: str
    path: Path
    extra: dict[str, Any] = field(default_factory=dict, repr=False)

    @classmethod
    def from_manifest_entry(cls, entry: dict[str, Any], artifacts_dir: Path) -> "Artifact":
        context = f"Artifact entry {entry.get('filename', '<unnamed>')!r}"
        known = {
            "filename",
            "profileId",
            "packageId",
            "version",
            "buildNumber",
            "artifactType",
            "abi",
            "distributionChannel",
            "sizeBytes",
            "sha256",
        }
        filename = str(_require(entry, "filename", context))
        if "/" in filename or "\\" in filename or filename in {"", ".", ".."}:
            raise ManifestError(f"{context} has an unsafe filename: {filename!r}")
        return cls(
            filename=filename,
            profile_id=str(_require(entry, "profileId", context)),
            package_id=str(_require(entry, "packageId", context)),
            version=str(_require(entry, "version", context)),
            build_number=str(_require(entry, "buildNumber", context)),
            artifact_type=str(_require(entry, "artifactType", context)),
            abi=str(entry.get("abi", "unknown")),
            distribution_channel=str(entry.get("distributionChannel", "unknown")),
            size_bytes=int(_require(entry, "sizeBytes", context)),
            sha256=str(_require(entry, "sha256", context)).lower(),
            path=artifacts_dir / filename,
            extra={key: value for key, value in entry.items() if key not in known},
        )

    def verify(self) -> None:
        """Fail loudly if the bytes on disk are not the bytes that were hashed."""
        if not self.path.is_file():
            raise ArtifactIntegrityError(f"Artifact is missing on disk: {self.path}")
        actual_size = self.path.stat().st_size
        if actual_size != self.size_bytes:
            raise ArtifactIntegrityError(
                f"{self.filename}: manifest says {self.size_bytes} bytes, "
                f"file on disk is {actual_size} bytes"
            )
        digest = hashlib.sha256()
        with self.path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(_CHUNK), b""):
                digest.update(chunk)
        actual_sha = digest.hexdigest()
        if actual_sha != self.sha256:
            raise ArtifactIntegrityError(
                f"{self.filename}: manifest sha256 {self.sha256} != on-disk {actual_sha}"
            )

    def to_dict(self) -> dict[str, Any]:
        return {
            "filename": self.filename,
            "profileId": self.profile_id,
            "packageId": self.package_id,
            "version": self.version,
            "buildNumber": self.build_number,
            "artifactType": self.artifact_type,
            "abi": self.abi,
            "distributionChannel": self.distribution_channel,
            "sizeBytes": self.size_bytes,
            "sha256": self.sha256,
        }


@dataclass(frozen=True)
class ReleaseMetadata:
    """A parsed release manifest: the contract every publisher consumes."""

    version: str
    build_number: str
    source_ref: str
    source_sha: str
    workflow_name: str
    workflow_run: str
    workflow_run_url: str
    generated_at: str
    artifacts: tuple[Artifact, ...]
    manifest_path: Path
    artifacts_dir: Path

    @classmethod
    def from_manifest_file(cls, manifest_path: Path) -> "ReleaseMetadata":
        manifest_path = manifest_path.expanduser().resolve()
        if not manifest_path.is_file():
            raise ManifestError(f"Release manifest not found: {manifest_path}")
        try:
            data = json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise ManifestError(f"Release manifest is not valid JSON: {manifest_path}: {exc}") from exc
        if not isinstance(data, dict):
            raise ManifestError(f"Release manifest must be a JSON object: {manifest_path}")

        schema_version = data.get("schemaVersion")
        if schema_version not in SUPPORTED_SCHEMA_VERSIONS:
            supported = ", ".join(str(value) for value in sorted(SUPPORTED_SCHEMA_VERSIONS))
            raise ManifestError(
                f"Unsupported release manifest schemaVersion {schema_version!r} "
                f"(supported: {supported})"
            )

        release = data.get("release")
        if not isinstance(release, dict):
            raise ManifestError("Release manifest is missing the 'release' object")

        raw_artifacts = data.get("artifacts")
        if not isinstance(raw_artifacts, list):
            raise ManifestError("Release manifest is missing the 'artifacts' array")

        artifacts_dir = manifest_path.parent
        artifacts = tuple(
            Artifact.from_manifest_entry(entry, artifacts_dir) for entry in raw_artifacts
        )

        return cls(
            version=str(_require(release, "version", "Release manifest 'release'")),
            build_number=str(release.get("buildNumber", "unknown")),
            source_ref=str(release.get("sourceRef", "unknown")),
            source_sha=str(release.get("sourceSha", "unknown")),
            workflow_name=str(release.get("workflowName", "unknown")),
            workflow_run=str(release.get("workflowRun", "unknown")),
            workflow_run_url=str(release.get("workflowRunUrl", "")),
            generated_at=str(data.get("generatedAt", "unknown")),
            artifacts=artifacts,
            manifest_path=manifest_path,
            artifacts_dir=artifacts_dir,
        )

    def verify_artifacts(self, artifacts: Iterable[Artifact] | None = None) -> None:
        for artifact in artifacts if artifacts is not None else self.artifacts:
            artifact.verify()

    def profile_ids(self) -> tuple[str, ...]:
        seen: list[str] = []
        for artifact in self.artifacts:
            if artifact.profile_id not in seen:
                seen.append(artifact.profile_id)
        return tuple(seen)

    def tag(self) -> str:
        """The GitHub Release tag this manifest describes."""
        return self.version


class PublishStatus(str, Enum):
    SUCCEEDED = "succeeded"
    SKIPPED = "skipped"
    DRY_RUN = "dry_run"
    STAGED = "staged"
    BLOCKED = "blocked"
    FAILED = "failed"

    @property
    def ok(self) -> bool:
        return self in {
            PublishStatus.SUCCEEDED,
            PublishStatus.SKIPPED,
            PublishStatus.DRY_RUN,
            PublishStatus.STAGED,
        }


@dataclass
class PublishResult:
    """What a publisher did, in a form that survives into CI job summaries."""

    target: str
    profile_id: str
    status: PublishStatus
    message: str
    artifacts: list[str] = field(default_factory=list)
    evidence: list[str] = field(default_factory=list)
    details: dict[str, Any] = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return self.status.ok

    def to_dict(self) -> dict[str, Any]:
        return {
            "target": self.target,
            "profileId": self.profile_id,
            "status": self.status.value,
            "message": self.message,
            "artifacts": list(self.artifacts),
            "evidence": list(self.evidence),
            "details": dict(self.details),
        }
