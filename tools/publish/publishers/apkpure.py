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
from ..errors import ConfigError
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
        artifact = ctx.sole_artifact()
        if artifact.artifact_type != "apk":
            raise ConfigError(
                f"{ctx.config.context}: APKPure distributes APKs, selector chose "
                f"{artifact.filename} ({artifact.artifact_type})."
            )
        package_id = ctx.config.package_id or artifact.package_id
        target_url = console_url(package_id)

        plan = {
            "packageId": package_id,
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
                    session.open_app_details(package_id)
                    session.upsert_description_notes(
                        artifact.version,
                        ctx.release_notes,
                        int(ctx.config.option("descriptionMaxChars", 1200)),
                    )
                    session.save_app_details()
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
