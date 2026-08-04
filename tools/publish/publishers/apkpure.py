"""APKPure publisher.

APKPure exposes no publishing API, so this drives their Developer Console with
Playwright. Two consequences shape the design:

* The run is only as trustworthy as its evidence. Every stage writes a
  screenshot and an HTML dump, and the final state is recorded as JSON.
* Nothing irreversible happens by default. Without ``--submit`` the APK is
  uploaded and the release notes are filled, but the version is left unsubmitted
  for a human to review in the console.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import ClassVar

from ..apkpure.console import (
    BrowserMode,
    console_session,
    resolve_browser_mode,
    resolve_browser_path,
)
from ..apkpure.console import DEFAULT_CDP_ENDPOINT
from ..apkpure.selectors import SelectorSet, console_url
from ..apk_inspect import coverage_report, inspect_apk
from ..upload_state import UploadState
from ..errors import ConfigError, CredentialError, RemoteError
from ..models import PublishResult, PublishStatus
from .base import Publisher, PublishContext

DEFAULT_STORAGE_STATE = Path.home() / ".config" / "airo" / "apkpure-session.json"


def storage_state_path(ctx: PublishContext) -> Path:
    configured = ctx.config.option("storageState") or ctx.env.get("APKPURE_STORAGE_STATE", "")
    return Path(configured).expanduser() if configured else DEFAULT_STORAGE_STATE


class ApkPurePublisher(Publisher):
    name: ClassVar[str] = "apkpure"
    description: ClassVar[str] = "APKPure Developer Console upload (Playwright, no public API)"
    needs_browser_session: ClassVar[bool] = True

    def preflight(self, ctx: PublishContext) -> list[str]:
        blockers = super().preflight(ctx)
        if not ctx.options.dry_run:
            # Only the bundled-Chromium mode replays a saved storage state; the
            # chrome and cdp modes carry their session in a real browser profile.
            mode = resolve_browser_mode(
            ctx.options.browser or ctx.config.option("browser"), ctx.env
        )
            state = storage_state_path(ctx)
            if mode is BrowserMode.BUNDLED and not state.is_file():
                blockers.append(
                    f"no APKPure session state at {state}; run "
                    "`python3 -m tools.publish login apkpure` first, or pass "
                    "browser=chrome/cdp in the target options"
                )
        return blockers

    def publish(self, ctx: PublishContext) -> PublishResult:
        artifacts = list(ctx.artifacts)
        wrong = [a for a in artifacts if a.artifact_type != "apk"]
        if wrong:
            raise ConfigError(
                f"{ctx.config.context}: APKPure distributes APKs, selector also chose "
                + ", ".join(f"{a.filename} ({a.artifact_type})" for a in wrong)
            )
        # Upload order is deliberate: the universal APK first, so the listing is
        # usable even if a later per-ABI upload is rejected or stalls in review.
        artifacts.sort(key=lambda a: (0 if _is_universal(a.filename) else 1, a.filename))
        package_id = ctx.config.package_id or artifacts[0].package_id

        # APKPure allows one version in flight at a time, so a multi-APK
        # release is many short runs rather than one long one. State is keyed
        # by content hash so a rebuilt APK of the same name is not mistaken for
        # one already accepted.
        # evidence.root is build/publish-evidence/<target>/<profile>/<version>;
        # the state belongs beside publish-evidence, not inside it.
        # What is inside the APK decides what devices it serves, so check it
        # before shipping rather than trusting the filename or the store's own
        # inferred label.
        expected = ctx.config.option("expectedAbis")
        if expected:
            expected_set = frozenset(expected)
            for candidate in artifacts:
                contents = inspect_apk(candidate.path)
                ctx.evidence.log(contents.describe())
                if contents.abis != expected_set:
                    raise ConfigError(
                        f"{ctx.config.context}: {candidate.filename} carries "
                        f"[{', '.join(sorted(contents.abis)) or 'none'}] but the listing "
                        f"expects [{', '.join(sorted(expected_set))}]. Refusing to upload: "
                        "the wrong slice would fail to install on the devices this "
                        "listing targets."
                    )
            # State the coverage this listing gives users, including what it
            # leaves out. A listing that silently serves one architecture is
            # how a 32-bit device owner finds out by failing to install.
            built = frozenset(
                abi
                for candidate in ctx.release.artifacts
                if candidate.artifact_type == "apk" and candidate.profile_id == ctx.profile_id
                for abi in inspect_apk(candidate.path).abis
            )
            coverage = coverage_report(expected_set, built)
            for line in coverage["served"]:
                ctx.evidence.log(f"serves {line}")
            for line in coverage["notServed"]:
                ctx.evidence.warn(f"NOT served by this listing: {line}")
            self._coverage = coverage

            max_mb = ctx.config.option("maxSizeMb")
            if max_mb:
                for candidate in artifacts:
                    size_mb = candidate.size_bytes / 1e6
                    if size_mb > float(max_mb):
                        raise ConfigError(
                            f"{ctx.config.context}: {candidate.filename} is "
                            f"{size_mb:.1f} MB, over the {max_mb} MB listing budget."
                        )

        state = UploadState.load(
            ctx.evidence.root.parents[3] / "publish-state", self.name, package_id
        )
        remaining = state.pending(artifacts)
        if not remaining:
            return self.result(
                ctx,
                PublishStatus.SKIPPED,
                f"All {len(artifacts)} APK(s) already accepted by APKPure for {package_id}",
                {"packageId": package_id, "accepted": sorted(a.filename for a in artifacts)},
            )
        artifact = remaining[0]
        ctx.evidence.log(
            f"{len(remaining)} of {len(artifacts)} APK(s) left; this run handles {artifact.filename}"
        )
        self._state = state
        self._remaining = remaining
        target_url = console_url(package_id)

        plan = {
            "packageId": package_id,
            "deviceCoverage": getattr(self, "_coverage", None),
            "consoleUrl": target_url,
            "apk": artifact.filename,
            "sha256": artifact.sha256,
            "version": artifact.version,
            "buildNumber": artifact.build_number,
            "abi": artifact.abi,
            "releaseNotesChars": len(ctx.release_notes),
            "willSubmit": ctx.options.may_submit,
        }
        ctx.evidence.write_json("apkpure-plan.json", plan)
        ctx.evidence.write_text("release-notes.txt", ctx.release_notes)

        if ctx.options.dry_run:
            return self.result(
                ctx,
                PublishStatus.DRY_RUN,
                f"Would upload {artifact.filename} to {target_url}",
                plan,
            )

        selectors = SelectorSet.load(ctx.config.option("selectorsFile"))
        ctx.evidence.log(f"selector source: {selectors.source}")
        mode = resolve_browser_mode(
            ctx.options.browser or ctx.config.option("browser"), ctx.env
        )
        # A real browser must be visible: a human may need to clear a challenge.
        headless = bool(ctx.config.option("headless", True)) and mode is BrowserMode.BUNDLED
        state = storage_state_path(ctx)

        with console_session(
            storage_state=state,
            evidence=ctx.evidence,
            selectors=selectors,
            headless=headless,
            timeout_ms=ctx.options.timeout_seconds * 1000,
            mode=mode,
            profile_dir=_optional_path(
                ctx.options.profile_dir or ctx.config.option("profileDir")
            ),
            cdp_endpoint=str(
                ctx.options.cdp_endpoint
                or ctx.config.option("cdpEndpoint", DEFAULT_CDP_ENDPOINT)
            ),
            browser_path=resolve_browser_path(
                ctx.options.browser_path or ctx.config.option("browserPath")
            ),
        ) as session:
            session.open_app(package_id)
            # The version table lives on /versions, so the duplicate check has
            # to happen after navigating there — on the app-details page it
            # silently finds nothing and skips the check entirely.
            session.open_upload_form()

            # Listing description: opt-in, and independent of the binary. Runs
            # before the upload branches so it still happens when the APK is
            # already published and there is nothing left to upload.
            if ctx.config.option("updateDescription"):
                if ctx.options.may_submit:
                    # Best effort: the listing form is locked while a publish
                    # review is in flight, and a cosmetic description update
                    # must never block shipping a binary.
                    try:
                        session.open_app_details(package_id)
                        session.upsert_description_notes(
                            artifact.version,
                            ctx.release_notes,
                            int(ctx.config.option("descriptionMaxChars", 1200)),
                        )
                        session.save_app_details()
                    except (RemoteError, CredentialError) as exc:
                        ctx.evidence.warn(f"listing description not updated: {exc}")
                    finally:
                        session.open_upload_form()
                else:
                    ctx.evidence.warn(
                        "skipping the listing description update: it edits public copy, "
                        "so it needs --submit"
                    )

            # The binary is already up and verified; only PUBLISH remains.
            # Re-attaching here would be pointless -- the Upload button is
            # disabled in this state -- so go straight to the publish step.
            if session.upload_awaiting_publish():
                ctx.evidence.log("an uploaded version has cleared verification; only PUBLISH remains")
                if not ctx.options.may_submit:
                    return self.result(
                        ctx,
                        PublishStatus.STAGED,
                        "An uploaded version has passed APKPure verification and is waiting "
                        "for PUBLISH; re-run with --submit to publish it",
                        {**plan, "uploadState": "verified-awaiting-publish"},
                    )
                session.submit_for_review(artifact.version)
                self._state.record(artifact.sha256, artifact.filename, artifact.version, "published")
                return self.result(
                    ctx,
                    PublishStatus.SUCCEEDED,
                    f"Published the verified {artifact.version} upload on APKPure",
                    {**plan, "uploadState": "published"},
                )

            # A version awaiting APKPure's manual review is absent from the
            # table, so the table alone cannot prove this version is not
            # already in flight. Re-uploading would queue it twice.
            if session.upload_is_pending_verification() and not ctx.options.force:
                ctx.evidence.warn("an upload is already awaiting APKPure verification")
                return self.result(
                    ctx,
                    PublishStatus.SKIPPED,
                    "An upload for this app is already under APKPure verification; "
                    "wait for it to clear, or pass --force",
                    plan,
                )

            existing = session.published_version_names()
            already = [name for name in existing if name == artifact.version]
            if already and not ctx.options.force:
                ctx.evidence.log(f"version {artifact.version} already listed")
                return self.result(
                    ctx,
                    PublishStatus.SKIPPED,
                    f"Version {artifact.version} already present on APKPure; pass --force to upload anyway",
                    {**plan, "existingVersion": already[0], "listedVersions": existing},
                )

            # APKPure permits one version in flight per app: while a previous
            # version is in publishing review the upload form is rendered but
            # its button is disabled. That is a queueing constraint, not a
            # failure, so it must not read as a broken release.
            if not session.upload_form_is_ready():
                ctx.evidence.warn(
                    "APKPure has a version in review; the upload form is locked. "
                    f"{len(remaining)} APK(s) still to upload."
                )
                return self.result(
                    ctx,
                    PublishStatus.SKIPPED,
                    f"APKPure is still reviewing a previous version; {len(remaining)} APK(s) "
                    "remain. Re-run once review clears.",
                    {**plan, "remaining": [a.filename for a in remaining], "blockedBy": "review"},
                )

            session.upload_apk(artifact.path)
            session.fill_release_notes(ctx.release_notes)

            if not ctx.options.may_submit:
                ctx.evidence.warn(
                    "Stopped before pressing Upload. The APK is attached in the browser "
                    "and the notes are filled, but nothing has been sent to APKPure. "
                    "Press Upload in the console yourself, or re-run with --submit."
                )
                return self.result(
                    ctx,
                    PublishStatus.STAGED,
                    f"Attached {artifact.filename} and filled release notes; nothing sent",
                    plan,
                )

            upload_state = session.send_upload(artifact.version)
            if upload_state == "pending":
                # APKPure reviews by hand. PUBLISH is meaningless until the
                # binary clears verification, and clicking it now would prove
                # nothing.
                ctx.evidence.log("upload queued for APKPure verification; not clicking PUBLISH")
                self._state.record(artifact.sha256, artifact.filename, artifact.version, "pending-verification")
                return self.result(
                    ctx,
                    PublishStatus.SUCCEEDED,
                    f"Uploaded {artifact.filename} to APKPure; awaiting their manual verification",
                    {**plan, "uploadState": "pending-verification"},
                )
            session.submit_for_review(artifact.version)

        ctx.evidence.write_json("apkpure-result.json", {**plan, "submitted": True})
        return self.result(
            ctx,
            PublishStatus.SUCCEEDED,
            f"Submitted {artifact.filename} to APKPure review for {package_id}",
            {**plan, "submitted": True},
        )


def _optional_path(value: object) -> Path | None:
    return Path(str(value)).expanduser() if value else None


def _is_universal(filename: str) -> bool:
    """True for the ABI-less APK (Airo-TV-0.0.6.apk, not ...-x86_64.apk)."""
    return not re.search(r"-(arm64-v8a|armeabi-v7a|x86_64|x86|arm64)\.apk$", filename, re.I)
