"""Tests for the tools/publish multi-store publishing framework.

These cover the parts a broken release would actually hurt: manifest integrity,
artifact selection, release-note resolution, submit gating, and the manual-store
escape hatch. No test contacts a store.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

from tools.publish.config import (  # noqa: E402
    ArtifactSelector,
    PublishConfig,
    ReleaseNotesSource,
)
from tools.publish.errors import (  # noqa: E402
    ArtifactIntegrityError,
    ConfigError,
    ManifestError,
    PreflightError,
)
from tools.publish.apkpure.console import ConsoleSession  # noqa: E402
from tools.publish.apkpure.console import (  # noqa: E402
    KNOWN_CHROMIUM_BROWSERS,
    BrowserMode,
    resolve_browser_mode,
    resolve_browser_path,
    supports_cdp,
)
from tools.publish.evidence import EvidenceRecorder  # noqa: E402
from tools.publish.fetch import FetchedRelease, index_manifests  # noqa: E402
from tools.publish.models import PublishStatus, ReleaseMetadata  # noqa: E402
from tools.publish.publishers import PublishContext, PublishOptions, get_publisher  # noqa: E402
sys.path.insert(0, str(REPO_ROOT / "scripts"))
from resolve_release_tv_apk import resolve_canonical_tv_apk  # noqa: E402
from tools.publish.runner import (  # noqa: E402
    RunRequest,
    exit_code_for,
    plan,
    run,
    summarise,
)

TV_APK = "Airo-TV-0.0.6.apk"
TV_AAB = "Airo-TV-0.0.6-Play-Store.aab"


def sha256_of(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_release(root: Path, *, corrupt: bool = False) -> Path:
    """Build a realistic artifacts directory plus its manifest."""
    artifacts_dir = root / "release-artifacts"
    artifacts_dir.mkdir(parents=True, exist_ok=True)

    entries = []
    for filename, payload, artifact_type, abi, channel in (
        (TV_APK, b"apk-bytes", "apk", "android-arm64", "direct-apk"),
        (TV_AAB, b"aab-bytes", "aab", "play-managed", "play-store"),
    ):
        path = artifacts_dir / filename
        path.write_bytes(payload)
        entries.append(
            {
                "filename": filename,
                "profileId": "tv",
                "packageId": "io.airo.app.tv",
                "version": "0.0.6",
                "buildNumber": "12",
                "artifactType": artifact_type,
                "abi": abi,
                "distributionChannel": channel,
                "sizeBytes": len(payload),
                "sha256": sha256_of(payload if not corrupt else b"tampered"),
            }
        )

    (artifacts_dir / "SHA256SUMS").write_text(
        "\n".join(f"{entry['sha256']}  {entry['filename']}" for entry in entries) + "\n",
        encoding="utf-8",
    )
    manifest = artifacts_dir / "Airo-TV-0.0.6-Release-Manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "generatedAt": "2026-08-04T00:00:00+00:00",
                "release": {
                    "version": "0.0.6",
                    "buildNumber": "12",
                    "sourceRef": "main",
                    "sourceSha": "deadbeef",
                    "workflowName": "Airo TV Release",
                    "workflowRun": "99",
                    "workflowRunUrl": "https://example.invalid/run/99",
                },
                "artifacts": entries,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return manifest


def write_config(root: Path, targets: dict) -> Path:
    path = root / "airo-publish-targets.json"
    path.write_text(json.dumps({"schemaVersion": 1, "targets": targets}, indent=2), encoding="utf-8")
    return path


def website_target(output_path: str = "docs/_data/downloads_tv.json") -> dict:
    return {
        "enabled": True,
        "profiles": {
            "tv": {
                "packageId": "io.airo.app.tv",
                "artifactSelector": {"artifactType": ["apk"], "minCount": 1, "maxCount": 1},
                "releaseNotes": {"source": "inline", "text": "Fixes and polish."},
                "options": {
                    "outputPath": output_path,
                    "downloadBaseUrl": "https://example.invalid/{version}",
                },
            }
        },
    }


class ManifestTests(unittest.TestCase):
    def test_parses_real_shaped_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            release = ReleaseMetadata.from_manifest_file(write_release(Path(tmp)))
            self.assertEqual(release.version, "0.0.6")
            self.assertEqual(release.build_number, "12")
            self.assertEqual(release.profile_ids(), ("tv",))
            self.assertEqual(len(release.artifacts), 2)

    def test_rejects_unsupported_schema_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            manifest = write_release(Path(tmp))
            data = json.loads(manifest.read_text(encoding="utf-8"))
            data["schemaVersion"] = 99
            manifest.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaises(ManifestError):
                ReleaseMetadata.from_manifest_file(manifest)

    def test_rejects_path_traversal_in_filename(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            manifest = write_release(Path(tmp))
            data = json.loads(manifest.read_text(encoding="utf-8"))
            data["artifacts"][0]["filename"] = "../escape.apk"
            manifest.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaises(ManifestError):
                ReleaseMetadata.from_manifest_file(manifest)

    def test_checksum_mismatch_is_caught_before_any_upload(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            release = ReleaseMetadata.from_manifest_file(write_release(Path(tmp), corrupt=True))
            with self.assertRaises(ArtifactIntegrityError):
                release.verify_artifacts()

    def test_missing_artifact_file_is_caught(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            manifest = write_release(Path(tmp))
            (manifest.parent / TV_APK).unlink()
            release = ReleaseMetadata.from_manifest_file(manifest)
            with self.assertRaises(ArtifactIntegrityError):
                release.verify_artifacts()


class SelectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.release = ReleaseMetadata.from_manifest_file(write_release(Path(self._tmp.name)))

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_selects_apk_only(self) -> None:
        selector = ArtifactSelector(artifact_types=("apk",))
        chosen = selector.select(self.release.artifacts, "test")
        self.assertEqual([a.filename for a in chosen], [TV_APK])

    def test_max_count_guards_ambiguous_selection(self) -> None:
        selector = ArtifactSelector(max_count=1)
        with self.assertRaises(ConfigError):
            selector.select(self.release.artifacts, "test")

    def test_min_count_guards_empty_selection(self) -> None:
        selector = ArtifactSelector(artifact_types=("macos_dmg",))
        with self.assertRaises(ConfigError):
            selector.select(self.release.artifacts, "test")

    def test_filename_pattern_picks_the_universal_apk(self) -> None:
        """A TV release ships several APKs, two of which are legitimately arm64.

        `Airo-TV-<v>.apk` (the universal build APKPure wants) and
        `Airo-TV-<v>-arm64-v8a.apk` both carry `abi: android-arm64`, so no
        `abi` selector can tell them apart. Selecting on the filename is exact.
        """
        artifacts = list(self.release.artifacts)
        for suffix in ("-arm64-v8a", "-armeabi-v7a", "-x86_64"):
            twin = artifacts[0]
            artifacts.append(
                type(twin)(
                    **{
                        **{f.name: getattr(twin, f.name) for f in twin.__dataclass_fields__.values()},
                        "filename": f"Airo-TV-0.0.6{suffix}.apk",
                    }
                )
            )
        by_abi = ArtifactSelector(artifact_types=("apk",), abis=("android-arm64",))
        self.assertEqual(len(by_abi.select(artifacts, "test")), 4)

        by_name = ArtifactSelector(
            artifact_types=("apk",), filename_pattern=r"^Airo-TV-{version}\.apk$", max_count=1
        )
        chosen = by_name.select(artifacts, "test")
        self.assertEqual([a.filename for a in chosen], [TV_APK])

    def test_filename_excludes_wins_over_contains(self) -> None:
        selector = ArtifactSelector(filename_contains=("Airo-TV",), filename_excludes=("Play-Store",))
        chosen = selector.select(self.release.artifacts, "test")
        self.assertEqual([a.filename for a in chosen], [TV_APK])


class ReleaseNotesTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.release = ReleaseMetadata.from_manifest_file(write_release(self.root))
        (self.root / "CHANGELOG.md").write_text(
            "# Changelog\n\n"
            "## [Airo TV v0.0.6] - 2026-08-04\n\n"
            "### Added\n\n- Guide favourites.\n\n"
            "## [Airo TV v0.0.5] - 2026-07-22\n\n- Older stuff.\n",
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_extracts_only_the_matching_section(self) -> None:
        source = ReleaseNotesSource(
            source="changelog",
            path="CHANGELOG.md",
            heading_pattern=r"^##\s+\[Airo TV v{version}\].*$",
        )
        notes = source.resolve(self.release, "tv", repo_root=self.root)
        self.assertIn("Guide favourites", notes)
        self.assertNotIn("Older stuff", notes)

    def test_truncates_to_max_chars(self) -> None:
        source = ReleaseNotesSource(source="inline", text="x" * 100, max_chars=10)
        notes = source.resolve(self.release, "tv", repo_root=self.root)
        self.assertEqual(len(notes), 10)
        self.assertTrue(notes.endswith("…"))

    def test_falls_back_when_no_section_matches(self) -> None:
        source = ReleaseNotesSource(
            source="changelog",
            path="CHANGELOG.md",
            heading_pattern=r"^##\s+\[Nothing v{version}\]$",
            fallback="Bug fixes.",
        )
        self.assertEqual(source.resolve(self.release, "tv", repo_root=self.root), "Bug fixes.")

    def test_empty_notes_without_fallback_is_an_error(self) -> None:
        source = ReleaseNotesSource(
            source="changelog",
            path="CHANGELOG.md",
            heading_pattern=r"^##\s+\[Nothing v{version}\]$",
        )
        with self.assertRaises(ConfigError):
            source.resolve(self.release, "tv", repo_root=self.root)

    def test_path_escaping_the_repo_is_rejected(self) -> None:
        source = ReleaseNotesSource(source="file", path="../../etc/passwd")
        with self.assertRaises(ConfigError):
            source.resolve(self.release, "tv", repo_root=self.root)


class ConfigTests(unittest.TestCase):
    def test_repo_config_is_valid_and_matches_build_profiles(self) -> None:
        config = PublishConfig.load()
        self.assertIn("github", config.target_names())
        build_profiles = json.loads(
            (REPO_ROOT / ".github" / "airo-build-profiles.json").read_text(encoding="utf-8")
        )
        known = {
            profile["id"]: profile.get("appId") for profile in build_profiles["profiles"]
        }
        for target in config.target_names():
            for profile in config.profiles_for(target):
                self.assertIn(
                    profile.profile_id,
                    known,
                    f"{profile.context} references a profile absent from airo-build-profiles.json",
                )
                if profile.package_id:
                    self.assertEqual(
                        profile.package_id,
                        known[profile.profile_id],
                        f"{profile.context} packageId disagrees with the build profile appId",
                    )

    def test_every_configured_target_has_a_publisher(self) -> None:
        config = PublishConfig.load()
        for target in config.target_names():
            self.assertIsNotNone(get_publisher(target))

    def test_unknown_target_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = write_config(Path(tmp), {"website": website_target()})
            config = PublishConfig.load(path)
            with self.assertRaises(ConfigError):
                config.profiles_for("nope")

    def test_unknown_profile_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = write_config(Path(tmp), {"website": website_target()})
            config = PublishConfig.load(path)
            with self.assertRaises(ConfigError):
                config.profiles_for("website", ["coins"])

    def test_bad_release_notes_source_is_rejected_at_load(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            target = website_target()
            target["profiles"]["tv"]["releaseNotes"] = {"source": "carrier-pigeon"}
            path = write_config(Path(tmp), {"website": target})
            with self.assertRaises(ConfigError):
                PublishConfig.load(path)


class RunnerTests(unittest.TestCase):
    def _request(self, root: Path, targets: dict, **option_kwargs) -> RunRequest:
        release = ReleaseMetadata.from_manifest_file(write_release(root))
        config = PublishConfig.load(write_config(root, targets))
        return RunRequest(
            release=release,
            config=config,
            targets=list(targets),
            profiles=None,
            options=PublishOptions(**option_kwargs),
            evidence_dir=root / "evidence",
            quiet=True,
        )

    def test_dry_run_needs_no_credentials_or_binaries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            targets = {
                "github": {
                    "enabled": True,
                    "profiles": {
                        "tv": {
                            "packageId": "io.airo.app.tv",
                            "artifactSelector": {"artifactType": ["apk"]},
                            "releaseNotes": {"source": "inline", "text": "Notes."},
                        }
                    },
                }
            }
            results = run(self._request(root, targets, dry_run=True))
            self.assertEqual([r.status for r in results], [PublishStatus.DRY_RUN])
            self.assertEqual(exit_code_for(results), 0)

    def test_disabled_target_is_skipped_not_run(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            targets = {"website": {**website_target(), "enabled": False}}
            results = run(self._request(root, targets))
            self.assertEqual([r.status for r in results], [PublishStatus.SKIPPED])

    def test_manual_store_reports_blocked_with_a_checklist(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            targets = {
                "amazon": {
                    "enabled": True,
                    "profiles": {
                        "tv": {
                            "packageId": "io.airo.app.tv",
                            "artifactSelector": {"artifactType": ["apk"], "maxCount": 1},
                            "releaseNotes": {"source": "inline", "text": "Notes."},
                        }
                    },
                }
            }
            results = run(self._request(root, targets))
            self.assertEqual([r.status for r in results], [PublishStatus.BLOCKED])
            checklist = Path(results[0].details["checklist"])
            self.assertTrue(checklist.is_file())
            self.assertIn("Amazon Developer Console", checklist.read_text(encoding="utf-8"))
            # Blocked must not read as success.
            self.assertEqual(exit_code_for(results), 2)

    def test_website_publisher_writes_download_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            relative = "build/test-downloads.json"
            results = run(self._request(root, {"website": website_target(relative)}))
            self.assertEqual([r.status for r in results], [PublishStatus.SUCCEEDED])
            output = REPO_ROOT / relative
            try:
                payload = json.loads(output.read_text(encoding="utf-8"))
                self.assertEqual(payload["version"], "0.0.6")
                self.assertEqual(payload["downloads"][0]["filename"], TV_APK)
                self.assertEqual(
                    payload["downloads"][0]["url"],
                    f"https://example.invalid/0.0.6/{TV_APK}",
                )
            finally:
                output.unlink(missing_ok=True)

    def test_website_output_path_cannot_escape_the_repository(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            results = run(self._request(root, {"website": website_target("../../escape.json")}))
            self.assertEqual([r.status for r in results], [PublishStatus.FAILED])
            self.assertIn("inside the repository", results[0].message)

    def test_corrupt_artifact_stops_the_run_before_publishing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            release = ReleaseMetadata.from_manifest_file(write_release(root, corrupt=True))
            config = PublishConfig.load(write_config(root, {"website": website_target()}))
            request = RunRequest(
                release=release,
                config=config,
                targets=["website"],
                profiles=None,
                options=PublishOptions(dry_run=True),
                evidence_dir=root / "evidence",
                quiet=True,
            )
            with self.assertRaises(ArtifactIntegrityError):
                run(request)

    def test_profile_absent_from_manifest_is_dropped_not_failed(self) -> None:
        """A TV-only release leg must not fail because the config also has `full`."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            targets = {"website": website_target()}
            targets["website"]["profiles"]["full"] = {
                "packageId": "io.airo.app",
                "artifactSelector": {"artifactType": ["apk"], "maxCount": 1},
                "releaseNotes": {"source": "inline", "text": "Notes."},
                "options": {"outputPath": "build/test-full.json"},
            }
            request = self._request(root, targets, dry_run=True)
            resolved = plan(request)
            self.assertEqual([cfg.profile_id for cfg, _ in resolved.contexts], ["tv"])
            self.assertEqual(
                [cfg.profile_id for cfg, _ in resolved.not_in_manifest], ["full"]
            )

    def test_explicitly_named_missing_profile_still_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            request = self._request(root, {"website": website_target()}, dry_run=True)
            request.profiles = ["coins"]
            with self.assertRaises(ConfigError):
                plan(request)

    def test_summary_renders_one_row_per_result(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            request = self._request(root, {"website": website_target()}, dry_run=True)
            results = run(request)
            summary = summarise(results, request.release)
            self.assertIn("| website | tv |", summary)
            self.assertIn("0.0.6", summary)


class SubmitGatingTests(unittest.TestCase):
    """The irreversible step must never happen implicitly."""

    def _context(self, root: Path, **option_kwargs) -> PublishContext:
        release = ReleaseMetadata.from_manifest_file(write_release(root))
        config = PublishConfig.load(
            write_config(
                root,
                {
                    "play": {
                        "enabled": True,
                        "profiles": {
                            "tv": {
                                "packageId": "io.airo.app.tv",
                                "artifactSelector": {"artifactType": ["aab"], "maxCount": 1},
                                "releaseNotes": {"source": "inline", "text": "Notes."},
                                "options": {"track": "internal"},
                            }
                        },
                    }
                },
            )
        )
        profile = config.profiles_for("play")[0]
        return PublishContext(
            release=release,
            config=profile,
            artifacts=profile.select_artifacts(release),
            options=PublishOptions(**option_kwargs),
            evidence=EvidenceRecorder(root=root / "evidence", quiet=True),
            release_notes="Notes.",
            env={"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": "{}"},
        )

    def test_without_submit_the_play_upload_only_stages(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ctx = self._context(Path(tmp))
            result = get_publisher("play").publish(ctx)
            self.assertEqual(result.status, PublishStatus.STAGED)
            self.assertIn("--submit", result.message)

    def test_dry_run_beats_submit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ctx = self._context(Path(tmp), dry_run=True, submit=True)
            self.assertFalse(ctx.options.may_submit)
            self.assertEqual(get_publisher("play").publish(ctx).status, PublishStatus.DRY_RUN)

    def test_play_rejects_a_non_aab_selection(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            release = ReleaseMetadata.from_manifest_file(write_release(root))
            config = PublishConfig.load(
                write_config(
                    root,
                    {
                        "play": {
                            "enabled": True,
                            "profiles": {
                                "tv": {
                                    "packageId": "io.airo.app.tv",
                                    "artifactSelector": {"artifactType": ["apk"], "maxCount": 1},
                                    "releaseNotes": {"source": "inline", "text": "Notes."},
                                    "options": {"track": "internal"},
                                }
                            },
                        }
                    },
                )
            )
            profile = config.profiles_for("play")[0]
            ctx = PublishContext(
                release=release,
                config=profile,
                artifacts=profile.select_artifacts(release),
                options=PublishOptions(submit=True),
                evidence=EvidenceRecorder(root=root / "evidence", quiet=True),
                release_notes="Notes.",
                env={"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": "{}"},
            )
            with self.assertRaises(ConfigError):
                get_publisher("play").publish(ctx)

    def test_invalid_track_is_a_preflight_blocker(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            release = ReleaseMetadata.from_manifest_file(write_release(root))
            config = PublishConfig.load(
                write_config(
                    root,
                    {
                        "play": {
                            "enabled": True,
                            "profiles": {
                                "tv": {
                                    "packageId": "io.airo.app.tv",
                                    "artifactSelector": {"artifactType": ["aab"], "maxCount": 1},
                                    "releaseNotes": {"source": "inline", "text": "Notes."},
                                    "options": {"track": "everyone"},
                                }
                            },
                        }
                    },
                )
            )
            profile = config.profiles_for("play")[0]
            ctx = PublishContext(
                release=release,
                config=profile,
                artifacts=profile.select_artifacts(release),
                options=PublishOptions(submit=True),
                evidence=EvidenceRecorder(root=root / "evidence", quiet=True),
                release_notes="Notes.",
                env={"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": "{}"},
            )
            blockers = get_publisher("play").preflight(ctx)
            self.assertTrue(any("track" in blocker for blocker in blockers), blockers)


class BrowserModeTests(unittest.TestCase):
    """APKPure sits behind Cloudflare; the answer is a real browser, not stealth."""

    def test_default_is_the_bundled_chromium(self) -> None:
        self.assertIs(resolve_browser_mode(None, {}), BrowserMode.BUNDLED)

    def test_env_selects_a_mode(self) -> None:
        self.assertIs(resolve_browser_mode(None, {"APKPURE_BROWSER": "cdp"}), BrowserMode.CDP)

    def test_config_beats_env(self) -> None:
        self.assertIs(
            resolve_browser_mode("chrome", {"APKPURE_BROWSER": "cdp"}), BrowserMode.CHROME
        )

    def test_unknown_mode_is_rejected(self) -> None:
        with self.assertRaises(PreflightError):
            resolve_browser_mode("firefox", {})

    def test_browser_path_shorthands_resolve_to_real_binaries(self) -> None:
        for name in ("arc", "brave", "chrome", "edge"):
            with self.subTest(browser=name):
                path = Path(KNOWN_CHROMIUM_BROWSERS[name])
                if not path.exists():
                    self.skipTest(f"{name} is not installed on this machine")
                self.assertEqual(resolve_browser_path(name), path)

    def test_browser_path_accepts_an_explicit_path(self) -> None:
        with tempfile.NamedTemporaryFile() as handle:
            self.assertEqual(resolve_browser_path(handle.name), Path(handle.name))

    def test_unknown_browser_path_is_rejected(self) -> None:
        with self.assertRaises(PreflightError):
            resolve_browser_path("/nonexistent/Browser.app/Contents/MacOS/Browser")

    def test_no_browser_path_means_playwrights_own_chrome_channel(self) -> None:
        self.assertIsNone(resolve_browser_path(None))

    @unittest.skipUnless(sys.platform == "darwin", "LaunchServices is macOS-only")
    def test_default_resolves_to_an_executable_browser(self) -> None:
        resolved = resolve_browser_path("default")
        self.assertIsNotNone(resolved)
        self.assertTrue(resolved.is_file(), resolved)

    def test_arc_is_known_not_to_expose_cdp(self) -> None:
        """Arc accepts --remote-debugging-port and never opens the port.

        Verified by probing Arc and Chrome identically: Chrome answered
        /json/version, Arc refused the connection. Without this guard the only
        symptom is ECONNREFUSED several steps after the real mistake.
        """
        arc = Path(KNOWN_CHROMIUM_BROWSERS["arc"])
        self.assertFalse(supports_cdp(arc))

    def test_mainstream_chromium_browsers_are_not_blocked(self) -> None:
        for name in ("chrome", "brave", "edge"):
            with self.subTest(browser=name):
                self.assertTrue(supports_cdp(Path(KNOWN_CHROMIUM_BROWSERS[name])))

    def test_bundled_chromium_is_not_blocked(self) -> None:
        self.assertTrue(supports_cdp(None))

    def _context(self, root: Path, options: dict) -> PublishContext:
        release = ReleaseMetadata.from_manifest_file(write_release(root))
        config = PublishConfig.load(
            write_config(
                root,
                {
                    "apkpure": {
                        "enabled": True,
                        "profiles": {
                            "tv": {
                                "packageId": "io.airo.app.tv",
                                "artifactSelector": {"artifactType": ["apk"], "maxCount": 1},
                                "releaseNotes": {"source": "inline", "text": "Notes."},
                                "options": options,
                            }
                        },
                    }
                },
            )
        )
        profile = config.profiles_for("apkpure")[0]
        return PublishContext(
            release=release,
            config=profile,
            artifacts=profile.select_artifacts(release),
            options=PublishOptions(),
            evidence=EvidenceRecorder(root=root / "evidence", quiet=True),
            release_notes="Notes.",
            env={},
        )

    def test_bundled_mode_still_requires_a_saved_session(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ctx = self._context(root, {"storageState": str(root / "absent.json")})
            blockers = get_publisher("apkpure").preflight(ctx)
            self.assertTrue(any("session state" in b for b in blockers), blockers)

    def test_chrome_and_cdp_modes_do_not_require_a_storage_state(self) -> None:
        for mode in ("chrome", "cdp"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                ctx = self._context(
                    root, {"browser": mode, "storageState": str(root / "absent.json")}
                )
                blockers = get_publisher("apkpure").preflight(ctx)
                self.assertEqual(blockers, [], f"{mode}: {blockers}")


class ApkPureVersionTableTests(unittest.TestCase):
    """Duplicate detection must not confuse a release with its release candidate."""

    class _FakeSession(ConsoleSession):
        def __init__(self, rows):  # noqa: D107 - test double
            self._rows = rows

        def published_versions(self):
            return self._rows

    LIVE_ROWS = [
        "0.0.6-rc.1\tAPK\t28.6 MB\t2026-08-03\tinfo",
        "0.0.5\tAPK\t30.6 MB\t2026-07-28\tinfo",
    ]

    def test_version_names_are_the_first_cell_only(self) -> None:
        session = self._FakeSession(self.LIVE_ROWS)
        self.assertEqual(session.published_version_names(), ["0.0.6-rc.1", "0.0.5"])

    def test_a_release_is_not_masked_by_its_release_candidate(self) -> None:
        """`"0.0.6" in "0.0.6-rc.1"` is True — a contains check would skip the release."""
        names = self._FakeSession(self.LIVE_ROWS).published_version_names()
        self.assertNotIn("0.0.6", names)
        self.assertIn("0.0.6-rc.1", names)

    def test_an_actually_published_version_is_detected(self) -> None:
        names = self._FakeSession(self.LIVE_ROWS).published_version_names()
        self.assertIn("0.0.5", names)

    def test_blank_and_detail_rows_are_dropped(self) -> None:
        session = self._FakeSession(["", "   ", "0.0.7\tAPK\t1 MB"])
        self.assertEqual(session.published_version_names(), ["0.0.7"])


class CanonicalApkAgreementTests(unittest.TestCase):
    """The publish selector and the release workflow must pick the same APK.

    `scripts/resolve_release_tv_apk.py` already defines "the canonical Airo TV
    APK" for the release workflows. This framework expresses the same rule
    declaratively as an `artifactSelector.filenamePattern`, so the two
    definitions are pinned together here rather than left to drift.
    """

    ASSETS = [
        "Airo-0.0.6-10-arm64.apk",
        "Airo-0.0.6-10-Play-Store.aab",
        "Airo-TV-0.0.6-arm64-v8a.apk",
        "Airo-TV-0.0.6-armeabi-v7a.apk",
        "Airo-TV-0.0.6-x86_64.apk",
        "Airo-TV-0.0.6-macOS.dmg",
        "Airo-TV-0.0.6.apk",
        "AiroCoins-0.0.6-10-arm64.apk",
    ]

    def test_selector_matches_the_workflow_resolver(self) -> None:
        expected = resolve_canonical_tv_apk(self.ASSETS)

        pattern = (
            PublishConfig.load()
            .profiles_for("apkpure")[0]
            .selector.filename_pattern
        )
        self.assertIsNotNone(pattern, "the apkpure selector must pin an exact filename")
        rendered = pattern.format(version=re.escape("0.0.6"), buildNumber="", profileId="")
        matched = [name for name in self.ASSETS if re.fullmatch(rendered, name)]

        self.assertEqual(matched, [expected])


class ManifestIndexTests(unittest.TestCase):
    """A release tag can carry a per-leg manifest and a combined one."""

    def _manifest(self, path: Path, entries: list[tuple[str, str]]) -> None:
        path.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "release": {"version": "0.0.6", "buildNumber": "10"},
                    "artifacts": [
                        {
                            "filename": filename,
                            "profileId": profile_id,
                            "packageId": "io.airo.app.tv",
                            "version": "0.0.6",
                            "buildNumber": "10",
                            "artifactType": "apk",
                            "abi": "android-arm64",
                            "distributionChannel": "direct-apk",
                            "sizeBytes": 1,
                            "sha256": sha256_of(b"x"),
                        }
                        for filename, profile_id in entries
                    ],
                }
            ),
            encoding="utf-8",
        )

    def test_prefers_the_manifest_covering_more_of_the_profile(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._manifest(root / "Airo-TV-0.0.6-Release-Manifest.json", [("a.apk", "tv"), ("b.apk", "tv")])
            self._manifest(
                root / "Airo-0.0.6-Release-Manifest.json",
                [("a.apk", "tv"), ("b.apk", "tv"), ("c.zip", "tv"), ("d.apk", "full")],
            )
            index = index_manifests(root)
            self.assertEqual(index["tv"].name, "Airo-0.0.6-Release-Manifest.json")
            self.assertEqual(index["full"].name, "Airo-0.0.6-Release-Manifest.json")

    def test_ambiguous_profile_requires_an_explicit_choice(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._manifest(root / "Airo-TV-0.0.6-Release-Manifest.json", [("a.apk", "tv")])
            self._manifest(root / "Airo-0.0.6-Release-Manifest.json", [("d.apk", "full")])
            fetched = FetchedRelease(tag="v0.0.6", directory=root, manifests=index_manifests(root))
            with self.assertRaises(ManifestError):
                fetched.manifest_for(None)
            self.assertEqual(fetched.manifest_for("tv").name, "Airo-TV-0.0.6-Release-Manifest.json")

    def test_unknown_profile_is_reported_with_the_available_ones(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._manifest(root / "Airo-TV-0.0.6-Release-Manifest.json", [("a.apk", "tv")])
            fetched = FetchedRelease(tag="v0.0.6", directory=root, manifests=index_manifests(root))
            with self.assertRaises(ManifestError) as caught:
                fetched.manifest_for("coins")
            self.assertIn("tv", str(caught.exception))

    def test_malformed_manifest_is_ignored_not_fatal(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "Broken-Release-Manifest.json").write_text("{not json", encoding="utf-8")
            self._manifest(root / "Airo-TV-0.0.6-Release-Manifest.json", [("a.apk", "tv")])
            self.assertEqual(sorted(index_manifests(root)), ["tv"])


class CliTests(unittest.TestCase):
    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, "-m", "tools.publish", *args],
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_targets_lists_every_publisher(self) -> None:
        result = self.run_cli("targets")
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ("github", "play", "apkpure", "amazon", "huawei", "fdroid", "website"):
            self.assertIn(name, result.stdout)

    def test_plan_emits_json_for_the_repo_config(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            manifest = write_release(Path(tmp))
            result = self.run_cli(
                "plan",
                "--manifest", str(manifest),
                "--target", "github",
                "--evidence-dir", str(Path(tmp) / "evidence"),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["release"]["version"], "0.0.6")
            self.assertEqual(payload["plan"][0]["target"], "github")
            self.assertEqual(payload["plan"][0]["packageId"], "io.airo.app.tv")

    def test_missing_manifest_exits_with_the_manifest_code(self) -> None:
        result = self.run_cli("plan", "--manifest", "/nonexistent/Release-Manifest.json")
        self.assertEqual(result.returncode, 2)
        self.assertIn("ManifestError", result.stderr)


if __name__ == "__main__":
    unittest.main()
