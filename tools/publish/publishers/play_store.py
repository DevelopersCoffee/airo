"""Google Play publisher.

Wraps `fastlane supply`, which the release workflows already call, so the Play
leg reads its package id, track, rollout, and AAB path from the same manifest
and publish config as every other store instead of from inline workflow YAML.
"""

from __future__ import annotations

import json
import tempfile
from pathlib import Path
from typing import ClassVar

from ..errors import ConfigError, CredentialError
from ..models import PublishResult, PublishStatus
from .base import Publisher, PublishContext

VALID_TRACKS = {"internal", "alpha", "beta", "production"}


class PlayStorePublisher(Publisher):
    name: ClassVar[str] = "play"
    description: ClassVar[str] = "Google Play track upload via fastlane supply"
    required_env: ClassVar[tuple[str, ...]] = ("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",)
    required_binaries: ClassVar[tuple[str, ...]] = ("fastlane",)

    def preflight(self, ctx: PublishContext) -> list[str]:
        blockers = super().preflight(ctx)
        track = ctx.config.option("track")
        if not track:
            blockers.append(f"{ctx.config.context}.options.track is required")
        elif track not in VALID_TRACKS:
            blockers.append(
                f"{ctx.config.context}.options.track must be one of "
                f"{', '.join(sorted(VALID_TRACKS))}, got {track!r}"
            )
        rollout = ctx.config.option("rollout")
        if rollout is not None:
            try:
                value = float(rollout)
            except (TypeError, ValueError):
                blockers.append(f"{ctx.config.context}.options.rollout must be a number 0..1")
            else:
                if not 0 <= value <= 1:
                    blockers.append(f"{ctx.config.context}.options.rollout must be between 0 and 1")
        return blockers

    def publish(self, ctx: PublishContext) -> PublishResult:
        artifact = ctx.sole_artifact()
        if artifact.artifact_type != "aab":
            raise ConfigError(
                f"{ctx.config.context}: Play uploads require an .aab, selector chose "
                f"{artifact.filename} ({artifact.artifact_type}). Set artifactSelector.artifactType to \"aab\"."
            )
        track = ctx.config.require_option("track")
        rollout = ctx.config.option("rollout")
        package_id = ctx.config.package_id or artifact.package_id

        details = {
            "packageName": package_id,
            "track": track,
            "rollout": rollout,
            "aab": artifact.filename,
            "versionName": artifact.version,
            "buildNumber": artifact.build_number,
        }

        if ctx.options.dry_run:
            ctx.evidence.write_json("play-plan.json", details)
            return self.result(
                ctx,
                PublishStatus.DRY_RUN,
                f"Would upload {artifact.filename} to Play {package_id} track={track}",
                details,
            )

        if not ctx.options.may_submit:
            ctx.evidence.write_json("play-plan.json", details)
            ctx.evidence.warn(
                "Play upload is an outward-facing action; re-run with --submit to perform it."
            )
            return self.result(
                ctx,
                PublishStatus.STAGED,
                f"Plan written; pass --submit to upload {artifact.filename} to track={track}",
                details,
            )

        credentials = ctx.require_env(
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
            "Provide the Play service account JSON (raw JSON or a path to the key file).",
        )
        with _service_account_file(credentials) as key_path:
            command = [
                "fastlane", "supply",
                "--package_name", package_id,
                "--aab", str(artifact.path),
                "--track", track,
                "--json_key", str(key_path),
                "--skip_upload_metadata", "true",
                "--skip_upload_images", "true",
                "--skip_upload_screenshots", "true",
            ]
            if rollout is not None:
                command += ["--rollout", str(rollout)]
            self.run(ctx, command, redact=(credentials, str(key_path)))

        ctx.evidence.write_json("play-upload.json", details)
        return self.result(
            ctx,
            PublishStatus.SUCCEEDED,
            f"Uploaded {artifact.filename} to Play {package_id} track={track}",
            details,
        )


class _service_account_file:
    """Materialise the service account JSON into a private temp file."""

    def __init__(self, credentials: str) -> None:
        self._credentials = credentials
        self._temp: Path | None = None

    def __enter__(self) -> Path:
        candidate = Path(self._credentials)
        if len(self._credentials) < 4096 and candidate.is_file():
            return candidate
        try:
            json.loads(self._credentials)
        except json.JSONDecodeError as exc:
            raise CredentialError(
                "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is neither a readable file path nor valid JSON"
            ) from exc
        handle = tempfile.NamedTemporaryFile(
            "w", suffix=".json", delete=False, encoding="utf-8"
        )
        with handle:
            handle.write(self._credentials)
        self._temp = Path(handle.name)
        self._temp.chmod(0o600)
        return self._temp

    def __exit__(self, *_exc: object) -> None:
        if self._temp is not None:
            self._temp.unlink(missing_ok=True)
