"""Publish-target configuration.

`.github/airo-publish-targets.json` says which stores exist, which release
profile maps to which store listing, which artifact each store wants, and where
release notes come from. Store-specific behaviour lives in a publisher; store
*configuration* lives here so adding a listing never means editing Python.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Sequence

from .errors import ConfigError
from .models import Artifact, ReleaseMetadata

SUPPORTED_SCHEMA_VERSIONS = frozenset({1})

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG_PATH = REPO_ROOT / ".github" / "airo-publish-targets.json"


def _as_tuple(value: Any, field_name: str) -> tuple[str, ...]:
    if value is None:
        return ()
    if isinstance(value, str):
        return (value,)
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return tuple(value)
    raise ConfigError(f"'{field_name}' must be a string or a list of strings, got {value!r}")


@dataclass(frozen=True)
class ArtifactSelector:
    """Declarative rule picking this store's artifacts out of the manifest."""

    artifact_types: tuple[str, ...] = ()
    abis: tuple[str, ...] = ()
    distribution_channels: tuple[str, ...] = ()
    filename_contains: tuple[str, ...] = ()
    filename_excludes: tuple[str, ...] = ()
    #: Regex over the whole filename, with {version}/{buildNumber}/{profileId}
    #: substituted from the artifact itself. Prefer this over `abi` when a store
    #: needs one exact file: it does not depend on manifest-inferred fields.
    filename_pattern: str | None = None
    #: Ordered regexes; the first that matches anything wins. Lets a store
    #: prefer a universal APK when the release built one and fall back to
    #: the arm64 build for releases that predate it.
    filename_preference: tuple[str, ...] = ()
    min_count: int = 1
    max_count: int | None = None

    @classmethod
    def from_dict(cls, data: Any, context: str) -> "ArtifactSelector":
        if data is None:
            return cls()
        if not isinstance(data, dict):
            raise ConfigError(f"{context}.artifactSelector must be an object")
        max_count = data.get("maxCount")
        if max_count is not None and (not isinstance(max_count, int) or max_count < 1):
            raise ConfigError(f"{context}.artifactSelector.maxCount must be a positive integer")
        min_count = data.get("minCount", 1)
        if not isinstance(min_count, int) or min_count < 0:
            raise ConfigError(f"{context}.artifactSelector.minCount must be a non-negative integer")
        pattern = data.get("filenamePattern")
        if pattern is not None:
            if not isinstance(pattern, str):
                raise ConfigError(f"{context}.artifactSelector.filenamePattern must be a string")
            try:
                re.compile(pattern.format(version="0", buildNumber="0", profileId="x"))
            except (re.error, KeyError, IndexError) as exc:
                raise ConfigError(
                    f"{context}.artifactSelector.filenamePattern is not a valid regex "
                    f"template: {exc}"
                ) from exc
        return cls(
            artifact_types=_as_tuple(data.get("artifactType"), f"{context}.artifactType"),
            abis=_as_tuple(data.get("abi"), f"{context}.abi"),
            distribution_channels=_as_tuple(
                data.get("distributionChannel"), f"{context}.distributionChannel"
            ),
            filename_contains=_as_tuple(data.get("filenameContains"), f"{context}.filenameContains"),
            filename_excludes=_as_tuple(data.get("filenameExcludes"), f"{context}.filenameExcludes"),
            filename_pattern=pattern,
            filename_preference=_as_tuple(
                data.get('filenamePreference'), f'{context}.filenamePreference'
            ),
            min_count=min_count,
            max_count=max_count,
        )

    def matches(self, artifact: Artifact) -> bool:
        name = artifact.filename.lower()
        if self.filename_pattern is not None:
            rendered = self.filename_pattern.format(
                version=re.escape(artifact.version),
                buildNumber=re.escape(artifact.build_number),
                profileId=re.escape(artifact.profile_id),
            )
            if not re.fullmatch(rendered, artifact.filename):
                return False
        if self.artifact_types and artifact.artifact_type not in self.artifact_types:
            return False
        if self.abis and artifact.abi not in self.abis:
            return False
        if self.distribution_channels and artifact.distribution_channel not in self.distribution_channels:
            return False
        if self.filename_contains and not any(token.lower() in name for token in self.filename_contains):
            return False
        if any(token.lower() in name for token in self.filename_excludes):
            return False
        return True

    def _preferred(self, artifacts: Sequence[Artifact]) -> list[Artifact] | None:
        for candidate_pattern in self.filename_preference:
            matched = []
            for artifact in artifacts:
                rendered = candidate_pattern.format(
                    version=re.escape(artifact.version),
                    buildNumber=re.escape(artifact.build_number),
                    profileId=re.escape(artifact.profile_id),
                )
                if re.fullmatch(rendered, artifact.filename):
                    matched.append(artifact)
            if matched:
                return matched
        return None

    def select(self, artifacts: Sequence[Artifact], context: str) -> list[Artifact]:
        if self.filename_preference:
            preferred = self._preferred(artifacts)
            if preferred is None:
                raise ConfigError(
                    f"{context}: none of the preferred filename patterns matched. "
                    f"Available: {', '.join(a.filename for a in artifacts)}"
                )
            return preferred
        chosen = [artifact for artifact in artifacts if self.matches(artifact)]
        if len(chosen) < self.min_count:
            raise ConfigError(
                f"{context}: artifact selector matched {len(chosen)} artifact(s), "
                f"needs at least {self.min_count}. Available: "
                + ", ".join(artifact.filename for artifact in artifacts)
            )
        if self.max_count is not None and len(chosen) > self.max_count:
            raise ConfigError(
                f"{context}: artifact selector matched {len(chosen)} artifact(s), "
                f"at most {self.max_count} allowed: "
                + ", ".join(artifact.filename for artifact in chosen)
            )
        return chosen


@dataclass(frozen=True)
class ReleaseNotesSource:
    """Where the 'What's New' text for a listing comes from."""

    source: str = "changelog"
    path: str | None = None
    text: str | None = None
    heading_pattern: str | None = None
    max_chars: int | None = None
    fallback: str | None = None

    @classmethod
    def from_dict(cls, data: Any, context: str) -> "ReleaseNotesSource":
        if data is None:
            return cls()
        if not isinstance(data, dict):
            raise ConfigError(f"{context}.releaseNotes must be an object")
        source = data.get("source", "changelog")
        if source not in {"changelog", "file", "inline"}:
            raise ConfigError(
                f"{context}.releaseNotes.source must be one of changelog|file|inline, got {source!r}"
            )
        if source in {"changelog", "file"} and not data.get("path"):
            raise ConfigError(f"{context}.releaseNotes.path is required for source={source}")
        if source == "inline" and not data.get("text"):
            raise ConfigError(f"{context}.releaseNotes.text is required for source=inline")
        max_chars = data.get("maxChars")
        if max_chars is not None and (not isinstance(max_chars, int) or max_chars < 1):
            raise ConfigError(f"{context}.releaseNotes.maxChars must be a positive integer")
        return cls(
            source=source,
            path=data.get("path"),
            text=data.get("text"),
            heading_pattern=data.get("headingPattern"),
            max_chars=max_chars,
            fallback=data.get("fallback"),
        )

    def resolve(self, release: ReleaseMetadata, profile_id: str, repo_root: Path = REPO_ROOT) -> str:
        if self.source == "inline":
            notes = (self.text or "").strip()
        else:
            notes = self._read_from_disk(release, profile_id, repo_root)
        if not notes:
            notes = (self.fallback or "").strip()
        if not notes:
            raise ConfigError(
                f"Release notes for profile {profile_id!r} resolved to an empty string. "
                "Add a matching CHANGELOG section, point releaseNotes.path at a real file, "
                "or set releaseNotes.fallback."
            )
        if self.max_chars is not None and len(notes) > self.max_chars:
            notes = notes[: self.max_chars - 1].rstrip() + "…"
        return notes

    def _read_from_disk(self, release: ReleaseMetadata, profile_id: str, repo_root: Path) -> str:
        raw_path = (self.path or "").format(
            version=release.version,
            buildNumber=release.build_number,
            profileId=profile_id,
        )
        # Resolve both sides: on macOS the temp dir and /var are symlinks, so an
        # unresolved root would reject perfectly legitimate paths.
        root = repo_root.resolve()
        resolved = (root / raw_path).resolve()
        try:
            resolved.relative_to(root)
        except ValueError as exc:
            raise ConfigError(f"releaseNotes.path must stay inside the repository: {resolved}") from exc
        if not resolved.is_file():
            if self.fallback:
                return ""
            raise ConfigError(f"Release notes file not found: {resolved}")
        content = resolved.read_text(encoding="utf-8")
        if self.source == "file":
            return content.strip()
        return self._extract_changelog_section(content, release, profile_id)

    def _extract_changelog_section(
        self, content: str, release: ReleaseMetadata, profile_id: str
    ) -> str:
        pattern = self.heading_pattern or r"^##\s+.*{version}.*$"
        rendered = pattern.format(
            version=re.escape(release.version),
            buildNumber=re.escape(release.build_number),
            profileId=re.escape(profile_id),
        )
        try:
            heading = re.compile(rendered, re.MULTILINE)
        except re.error as exc:
            raise ConfigError(f"releaseNotes.headingPattern is not a valid regex: {exc}") from exc
        match = heading.search(content)
        if not match:
            return ""
        rest = content[match.end() :]
        next_heading = re.search(r"^##\s+", rest, re.MULTILINE)
        section = rest[: next_heading.start()] if next_heading else rest
        return section.strip()


@dataclass(frozen=True)
class TargetProfileConfig:
    """One store listing for one release profile."""

    target: str
    profile_id: str
    enabled: bool
    package_id: str | None
    selector: ArtifactSelector
    release_notes: ReleaseNotesSource
    options: dict[str, Any] = field(default_factory=dict)

    @property
    def context(self) -> str:
        return f"targets.{self.target}.profiles.{self.profile_id}"

    def option(self, key: str, default: Any = None) -> Any:
        return self.options.get(key, default)

    def require_option(self, key: str) -> Any:
        if key not in self.options or self.options[key] in (None, ""):
            raise ConfigError(f"{self.context}.options.{key} is required but not set")
        return self.options[key]

    def select_artifacts(self, release: ReleaseMetadata) -> list[Artifact]:
        candidates = [a for a in release.artifacts if a.profile_id == self.profile_id]
        if not candidates:
            raise ConfigError(
                f"{self.context}: release manifest has no artifacts for profile {self.profile_id!r}. "
                f"Manifest profiles: {', '.join(release.profile_ids()) or '<none>'}"
            )
        if self.package_id:
            mismatched = [a for a in candidates if a.package_id != self.package_id]
            candidates = [a for a in candidates if a.package_id == self.package_id]
            if not candidates:
                raise ConfigError(
                    f"{self.context}: no artifact has packageId {self.package_id!r}. "
                    f"Saw: {', '.join(sorted({a.package_id for a in mismatched}))}"
                )
        return self.selector.select(candidates, self.context)


@dataclass(frozen=True)
class PublishConfig:
    """The whole `.github/airo-publish-targets.json` file."""

    path: Path
    targets: dict[str, dict[str, TargetProfileConfig]]
    target_enabled: dict[str, bool]

    @classmethod
    def load(cls, path: Path | None = None) -> "PublishConfig":
        config_path = (path or DEFAULT_CONFIG_PATH).expanduser().resolve()
        if not config_path.is_file():
            raise ConfigError(f"Publish target config not found: {config_path}")
        try:
            data = json.loads(config_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise ConfigError(f"Publish target config is not valid JSON: {config_path}: {exc}") from exc
        if not isinstance(data, dict):
            raise ConfigError(f"Publish target config must be a JSON object: {config_path}")
        if data.get("schemaVersion") not in SUPPORTED_SCHEMA_VERSIONS:
            supported = ", ".join(str(value) for value in sorted(SUPPORTED_SCHEMA_VERSIONS))
            raise ConfigError(
                f"Unsupported publish config schemaVersion {data.get('schemaVersion')!r} "
                f"(supported: {supported})"
            )

        raw_targets = data.get("targets")
        if not isinstance(raw_targets, dict) or not raw_targets:
            raise ConfigError("Publish target config needs a non-empty 'targets' object")

        targets: dict[str, dict[str, TargetProfileConfig]] = {}
        target_enabled: dict[str, bool] = {}
        for target_name, raw_target in raw_targets.items():
            if not isinstance(raw_target, dict):
                raise ConfigError(f"targets.{target_name} must be an object")
            target_enabled[target_name] = bool(raw_target.get("enabled", True))
            raw_profiles = raw_target.get("profiles")
            if not isinstance(raw_profiles, dict) or not raw_profiles:
                raise ConfigError(f"targets.{target_name}.profiles must be a non-empty object")
            profiles: dict[str, TargetProfileConfig] = {}
            for profile_id, raw_profile in raw_profiles.items():
                if not isinstance(raw_profile, dict):
                    raise ConfigError(f"targets.{target_name}.profiles.{profile_id} must be an object")
                context = f"targets.{target_name}.profiles.{profile_id}"
                options = raw_profile.get("options", {})
                if not isinstance(options, dict):
                    raise ConfigError(f"{context}.options must be an object")
                profiles[profile_id] = TargetProfileConfig(
                    target=target_name,
                    profile_id=profile_id,
                    enabled=bool(raw_profile.get("enabled", True)),
                    package_id=raw_profile.get("packageId"),
                    selector=ArtifactSelector.from_dict(raw_profile.get("artifactSelector"), context),
                    release_notes=ReleaseNotesSource.from_dict(raw_profile.get("releaseNotes"), context),
                    options=options,
                )
            targets[target_name] = profiles

        return cls(path=config_path, targets=targets, target_enabled=target_enabled)

    def target_names(self) -> tuple[str, ...]:
        return tuple(sorted(self.targets))

    def is_target_enabled(self, target: str) -> bool:
        return self.target_enabled.get(target, False)

    def profiles_for(self, target: str, profile_filter: Sequence[str] | None = None) -> list[TargetProfileConfig]:
        if target not in self.targets:
            raise ConfigError(
                f"Unknown publish target {target!r}. Configured: {', '.join(self.target_names())}"
            )
        profiles = self.targets[target]
        if profile_filter:
            missing = [p for p in profile_filter if p not in profiles]
            if missing:
                raise ConfigError(
                    f"targets.{target} has no profile(s) {', '.join(missing)}. "
                    f"Configured: {', '.join(sorted(profiles))}"
                )
            return [profiles[p] for p in profile_filter]
        return [profiles[key] for key in sorted(profiles)]
