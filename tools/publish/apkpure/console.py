"""Playwright driver for the APKPure Developer Console.

Scope boundaries, deliberately:

* **No password handling.** This module never types credentials. A human signs
  in once through ``python3 -m tools.publish login apkpure``, which opens a
  headed browser and saves the resulting session state. CI reuses that state.
* **No CAPTCHA or 2FA solving.** If a challenge appears, the run stops with a
  screenshot and asks a human to take over.
* **No final submit unless asked.** Upload and release notes are staged; the
  irreversible "Submit for Review" click happens only with ``--submit``.
"""

from __future__ import annotations

import contextlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Iterator

from ..errors import CredentialError, PreflightError, RemoteError
from ..evidence import EvidenceRecorder
from .selectors import SIGN_IN_URL, SelectorSet, console_url

DEFAULT_VIEWPORT = {"width": 1440, "height": 900}


def import_playwright() -> Any:
    try:
        from playwright.sync_api import sync_playwright  # noqa: PLC0415
    except ImportError as exc:  # pragma: no cover - depends on the environment
        raise PreflightError(
            "playwright is not installed. Install it with:\n"
            "  python3 -m pip install playwright\n"
            "  python3 -m playwright install chromium"
        ) from exc
    return sync_playwright


@dataclass
class ConsoleSession:
    """A signed-in APKPure console page plus the helpers the publisher needs."""

    page: Any
    selectors: SelectorSet
    evidence: EvidenceRecorder
    timeout_ms: int = 60_000
    _snapshot_index: int = 0

    # ---- low-level selector handling ----------------------------------------

    def _first_visible(self, key: str, timeout_ms: int | None = None) -> Any | None:
        """Return the first candidate locator that is actually visible."""
        deadline = timeout_ms if timeout_ms is not None else self.timeout_ms
        per_candidate = max(1_000, deadline // max(1, len(self.selectors.candidates(key))))
        for candidate in self.selectors.candidates(key):
            locator = self.page.locator(candidate).first
            try:
                locator.wait_for(state="visible", timeout=per_candidate)
            except Exception:  # noqa: BLE001 - Playwright raises its own TimeoutError
                continue
            self.evidence.log(f"selector {key!r} matched: {candidate}")
            return locator
        return None

    def require(self, key: str, what: str, timeout_ms: int | None = None) -> Any:
        locator = self._first_visible(key, timeout_ms)
        if locator is None:
            self.snapshot(f"missing-{key}")
            raise RemoteError(
                f"Could not find {what} on the APKPure console "
                f"(selector key {key!r}, source {self.selectors.source}). "
                "The console DOM likely changed: re-run "
                "`python3 -m tools.publish doctor apkpure` and update the selector override."
            )
        return locator

    def present(self, key: str, timeout_ms: int = 3_000) -> bool:
        return self._first_visible(key, timeout_ms) is not None

    # ---- evidence -----------------------------------------------------------

    def snapshot(self, label: str) -> list[Path]:
        self._snapshot_index += 1
        stem = f"{self._snapshot_index:02d}-{label}"
        written: list[Path] = []
        with contextlib.suppress(Exception):
            png = self.evidence.file_path(f"{stem}.png")
            self.page.screenshot(path=str(png), full_page=True)
            written.append(png)
        with contextlib.suppress(Exception):
            written.append(self.evidence.write_text(f"{stem}.html", self.page.content()))
        self.evidence.log(f"snapshot {stem} ({self.page.url})")
        return written

    # ---- flow steps ---------------------------------------------------------

    def guard_human_gate(self, stage: str) -> None:
        """Stop rather than attempt any CAPTCHA, 2FA, or device challenge."""
        if self.present("human_gate_marker", timeout_ms=2_000):
            self.snapshot(f"human-gate-{stage}")
            raise CredentialError(
                f"APKPure presented a human verification challenge at stage {stage!r}. "
                "This tool does not solve challenges. Re-run "
                "`python3 -m tools.publish login apkpure` on a machine with a display, "
                "clear the challenge by hand, and retry with the refreshed session."
            )

    def open_app(self, package_id: str) -> None:
        url = console_url(package_id)
        self.evidence.log(f"opening {url}")
        self.page.goto(url, wait_until="domcontentloaded", timeout=self.timeout_ms)
        self.guard_human_gate("open")
        if self.present("sign_in_marker", timeout_ms=5_000):
            self.snapshot("signed-out")
            raise CredentialError(
                "APKPure session is not signed in or has expired. Run "
                "`python3 -m tools.publish login apkpure` to refresh the saved session state."
            )
        self.require("signed_in_marker", "a signed-in console shell", timeout_ms=15_000)
        self.snapshot("console")

    def published_versions(self) -> list[str]:
        """Best-effort read of the versions already listed for this app."""
        rows = self._first_visible("version_row", timeout_ms=8_000)
        if rows is None:
            self.evidence.warn("Could not read the versions table; skipping duplicate check")
            return []
        texts: list[str] = []
        for candidate in self.selectors.candidates("version_row"):
            locator = self.page.locator(candidate)
            count = locator.count()
            if count:
                texts = [(locator.nth(index).inner_text() or "").strip() for index in range(count)]
                break
        return [text for text in texts if text]

    def open_upload_form(self) -> None:
        link = self._first_visible("manage_versions_link", timeout_ms=10_000)
        if link is not None:
            link.click()
            self.page.wait_for_load_state("domcontentloaded", timeout=self.timeout_ms)
            self.snapshot("manage-versions")
        button = self._first_visible("new_version_button", timeout_ms=10_000)
        if button is not None:
            button.click()
            self.snapshot("new-version-form")
        self.guard_human_gate("upload-form")

    def upload_apk(self, apk_path: Path) -> None:
        file_input = self.require("apk_file_input", "the APK file input")
        self.evidence.log(f"attaching {apk_path.name} ({apk_path.stat().st_size} bytes)")
        file_input.set_input_files(str(apk_path))
        if self.present("upload_error_marker", timeout_ms=5_000):
            self.snapshot("upload-error")
            raise RemoteError(
                "APKPure reported an error immediately after attaching the APK. "
                "See the snapshot in the evidence directory."
            )
        if self._first_visible("upload_complete_marker", timeout_ms=self.timeout_ms) is None:
            self.snapshot("upload-unconfirmed")
            raise RemoteError(
                "APK upload never reported completion within the timeout. "
                "The console may still be processing; check the snapshot before retrying."
            )
        self.snapshot("upload-complete")

    def fill_release_notes(self, notes: str) -> None:
        field = self.require("release_notes_input", "the What's New field")
        field.fill(notes)
        self.snapshot("release-notes")

    def submit_for_review(self) -> None:
        button = self.require("submit_button", "the Submit for Review button")
        button.click()
        confirm = self._first_visible("submit_confirm_button", timeout_ms=5_000)
        if confirm is not None:
            confirm.click()
        self.guard_human_gate("submit")
        if self._first_visible("submit_success_marker", timeout_ms=self.timeout_ms) is None:
            self.snapshot("submit-unconfirmed")
            raise RemoteError(
                "Submitted, but APKPure never showed a review-status confirmation. "
                "Check the console by hand before re-running: a blind retry may create a "
                "duplicate submission."
            )
        self.snapshot("submitted")


@contextlib.contextmanager
def console_session(
    *,
    storage_state: Path,
    evidence: EvidenceRecorder,
    selectors: SelectorSet,
    headless: bool = True,
    timeout_ms: int = 60_000,
) -> Iterator[ConsoleSession]:
    """Open a Chromium context restored from a saved, human-created session."""
    if not storage_state.is_file():
        raise CredentialError(
            f"No APKPure session state at {storage_state}. Run "
            "`python3 -m tools.publish login apkpure` on a machine with a display first."
        )
    sync_playwright = import_playwright()
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=headless)
        try:
            context = browser.new_context(
                storage_state=str(storage_state),
                viewport=DEFAULT_VIEWPORT,
                accept_downloads=False,
            )
            context.set_default_timeout(timeout_ms)
            page = context.new_page()
            page.on("console", lambda msg: evidence.log(f"browser console [{msg.type}] {msg.text}"))
            try:
                yield ConsoleSession(
                    page=page, selectors=selectors, evidence=evidence, timeout_ms=timeout_ms
                )
            finally:
                # Refresh the stored session so a rolling cookie does not expire
                # the automation between releases.
                with contextlib.suppress(Exception):
                    context.storage_state(path=str(storage_state))
                context.close()
        finally:
            browser.close()


def interactive_login(
    storage_state: Path,
    evidence: EvidenceRecorder,
    confirm: Callable[[str], object] = input,
) -> Path:
    """Open a headed browser so a human can sign in, then save the session.

    The human types their own credentials into APKPure's own page. Nothing about
    the credentials passes through this process — only the resulting cookies are
    saved, and only after the human confirms in the terminal. Confirming there
    rather than waiting for the window to close means the session is captured
    while the browser is still alive, so closing the whole window (rather than
    just the tab) does not throw the sign-in away.
    """
    sync_playwright = import_playwright()
    storage_state.parent.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=False)
        context = browser.new_context(viewport=DEFAULT_VIEWPORT)
        page = context.new_page()
        page.goto(SIGN_IN_URL, wait_until="domcontentloaded")
        evidence.log(f"opened {SIGN_IN_URL} for interactive sign-in")
        confirm(
            "\nSign in to APKPure in the browser window that just opened.\n"
            "Leave the window OPEN, then press Enter here to save the session: "
        )
        try:
            context.storage_state(path=str(storage_state))
        except Exception as exc:  # noqa: BLE001 - Playwright raises its own errors
            raise CredentialError(
                f"Could not read the browser session: {exc}. "
                "Keep the browser window open until after you press Enter."
            ) from exc
        finally:
            with contextlib.suppress(Exception):
                context.close()
            with contextlib.suppress(Exception):
                browser.close()

    if not storage_state.is_file():
        raise CredentialError(f"No session state was written to {storage_state}.")
    storage_state.chmod(0o600)
    try:
        cookies = json.loads(storage_state.read_text(encoding="utf-8")).get("cookies") or []
    except (json.JSONDecodeError, AttributeError):
        cookies = []
    if not cookies:
        raise CredentialError(
            f"{storage_state} holds no cookies, so sign-in did not complete. "
            "Re-run and press Enter only after the developer console is visible."
        )
    evidence.log(f"saved {len(cookies)} cookie(s) to {storage_state}")
    return storage_state
