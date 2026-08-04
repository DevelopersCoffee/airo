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
import re
import plistlib
import sys
from dataclasses import dataclass
from enum import Enum
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

    def require_enabled(self, key: str, what: str, timeout_ms: int | None = None) -> Any:
        """require(), but refuses a control the page has disabled.

        Playwright retries a click on a disabled element until the timeout
        expires, which turns "APKPure disabled this button on purpose" into a
        ten-minute hang with no explanation.
        """
        locator = self.require(key, what, timeout_ms)
        # Materialize marks controls dead with a CSS class, not the disabled
        # attribute, so is_enabled() reports True for a button the page will
        # ignore. Clicking it silently does nothing -- which is how a listing
        # edit can appear to succeed while changing nothing at all.
        class_disabled = locator.evaluate(
            "e => (e.className || '').split(/\\s+/).includes('disabled') "
            "|| e.getAttribute('aria-disabled') === 'true'"
        )
        if class_disabled or not locator.is_enabled():
            self.snapshot(f"disabled-{key}")
            raise RemoteError(
                f"{what} is present but disabled, so the console is not in a state that "
                "accepts this action. See the snapshot in the evidence directory."
            )
        return locator

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

    def open_app_details(self, package_id: str) -> None:
        """Navigate to the APP DETAILS tab for this package."""
        url = console_url(package_id)
        if self.page.url.rstrip("/") != url.rstrip("/"):
            self.page.goto(url, wait_until="domcontentloaded", timeout=self.timeout_ms)
        self.page.wait_for_timeout(1_500)
        self.guard_human_gate("app-details")
        self.snapshot("app-details")

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

    def published_version_names(self) -> list[str]:
        """Just the version cell of each row.

        Substring matching is not safe here: "0.0.6" is a substring of the
        "0.0.6-rc.1" row that a release candidate leaves behind, so a contains
        check would treat the real 0.0.6 as already published and skip it.
        """
        names = []
        for row in self.published_versions():
            first = re.split(r"[\t\n]", row.strip(), maxsplit=1)[0].strip()
            if first:
                names.append(first)
        return names

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
        """Attach the APK. Nothing is sent to APKPure by this step.

        The console's uploader is a Vue component that reads the file locally,
        clears the native input, and renders the filename. Transmission happens
        only when the form's Upload button is pressed, which is a separate,
        gated step.
        """
        file_input = self.require("apk_file_input", "the APK file input")
        self.evidence.log(f"attaching {apk_path.name} ({apk_path.stat().st_size} bytes)")
        file_input.set_input_files(str(apk_path))
        if self.present("upload_error_marker", timeout_ms=5_000):
            self.snapshot("upload-error")
            raise RemoteError(
                "APKPure reported an error immediately after attaching the APK. "
                "See the snapshot in the evidence directory."
            )
        accepted = self._first_visible("upload_accepted_marker", timeout_ms=30_000)
        if accepted is None:
            self.snapshot("attach-unconfirmed")
            raise RemoteError(
                "The console never displayed the attached filename, so the uploader did "
                "not accept the file. Nothing was sent."
            )
        shown = (accepted.inner_text() or "").strip()
        if apk_path.name not in shown:
            self.snapshot("attach-mismatch")
            raise RemoteError(
                f"The console shows {shown!r} attached but this run selected "
                f"{apk_path.name!r}. Refusing to continue with the wrong file."
            )
        self.evidence.log(f"uploader accepted {shown}")
        self.snapshot("apk-attached")

    def send_upload(self, expected_version: str | None = None) -> str:
        """Press the form's Upload button. This transmits the APK.

        Returns "pending" when APKPure has queued the APK for its manual review,
        or "listed" when the version is already visible in the table. Both are
        success: APKPure verifies every upload by hand, so the version row can
        be hours or days away and cannot be the completion signal.
        """
        button = self.require_enabled("upload_submit_button", "the form's Upload button")
        self.evidence.log("pressing Upload — this sends the APK to APKPure")
        button.click()
        self.guard_human_gate("upload")

        # Check the explicit error text first; the pending notice and the error
        # notice share a container, so order matters.
        if self._first_visible("upload_error_marker", timeout_ms=8_000) is not None:
            self.snapshot("upload-error")
            raise RemoteError("APKPure reported an error while uploading the APK.")

        pending = self._first_visible("upload_pending_marker", timeout_ms=120_000)
        if pending is not None:
            self.evidence.log(f"APKPure queued the upload: {(pending.inner_text() or '').strip()[:120]}")
            self.snapshot("upload-pending-verification")
            return "pending"

        if expected_version and self._await_version_row(expected_version, attempts=5):
            self.snapshot("upload-listed")
            return "listed"

        self.snapshot("upload-unconfirmed")
        raise RemoteError(
            "Pressed Upload but saw neither the verification notice nor a new version row"
            + (f" for {expected_version}" if expected_version else "")
            + ". Check the console by hand before retrying: a blind retry may upload twice."
        )

    def upload_is_pending_verification(self) -> bool:
        """True when a previous upload is still in APKPure's review queue."""
        return self.present("upload_pending_marker", timeout_ms=6_000)

    def upload_awaiting_publish(self) -> bool:
        """True when an uploaded version has cleared verification.

        In this state the binary is already on APKPure and the Upload button is
        disabled; only the app-level PUBLISH click remains.
        """
        return self.present("upload_verified_marker", timeout_ms=6_000)

    @staticmethod
    def plain_text_notes(markdown: str) -> str:
        """Flatten CHANGELOG markdown into store-listing prose.

        A store description is plain text: "### Added" and
        "[label](url)" render literally, so the source markdown has to be
        converted rather than pasted.
        """
        lines: list[str] = []
        for raw in markdown.splitlines():
            line = raw.rstrip()
            # [label](url) -> label (url), or just the url when the label is the url
            line = re.sub(
                r"\[([^\]]+)\]\(([^)]+)\)",
                lambda m: m.group(2) if m.group(1) == m.group(2) else f"{m.group(1)} ({m.group(2)})",
                line,
            )
            line = re.sub(r"`([^`]*)`", r"\1", line)          # inline code
            line = re.sub(r"\*\*([^*]+)\*\*", r"\1", line)     # bold
            heading = re.match(r"^\s*#{1,6}\s+(.*)$", line)
            if heading:
                lines.append("")
                lines.append(f"{heading.group(1).strip()}:")
                continue
            bullet = re.match(r"^\s*[-*]\s+(.*)$", line)
            if bullet:
                lines.append(f"\u2022 {bullet.group(1).strip()}")
                continue
            lines.append(line.strip())
        text = "\n".join(lines)
        text = re.sub(r"\n{3,}", "\n\n", text)
        return text.strip()

    #: Delimiters for the release-notes block this tool owns inside the
    #: listing description. Everything between them is replaced on each
    #: release; everything outside is the maintainer's copy and is never
    #: touched. Without markers, each release would append another changelog
    #: and the description would grow without bound.
    NOTES_BEGIN = "--- What's new (maintained by airo publish) ---"
    NOTES_END = "--- end what's new ---"

    def upsert_description_notes(self, version: str, notes: str, max_chars: int = 1200) -> str:
        """Insert or replace the release-notes block in the listing description."""
        field = self.require("description_input", "the listing description field")
        current = field.input_value()

        body = self.plain_text_notes(notes)
        if len(body) > max_chars:
            body = body[: max_chars - 1].rstrip() + "\u2026"
        block = f"{self.NOTES_BEGIN}\nv{version}\n{body}\n{self.NOTES_END}"

        start = current.find(self.NOTES_BEGIN)
        end = current.find(self.NOTES_END)
        if start != -1 and end != -1 and end > start:
            updated = current[:start] + block + current[end + len(self.NOTES_END) :]
            self.evidence.log("replacing the existing release-notes block in the description")
        else:
            updated = current.rstrip() + "\n\n" + block
            self.evidence.log("appending a release-notes block to the description")

        if updated == current:
            self.evidence.log("description already up to date")
            return updated
        field.fill(updated)
        self.snapshot("description-updated")
        return updated

    def save_app_details(self) -> None:
        button = self.require_enabled("app_details_submit", "the APP DETAILS save button")
        self.evidence.log("saving APP DETAILS — this updates the public listing")
        button.click()
        self.guard_human_gate("app-details")
        self.snapshot("app-details-saved")

    def fill_release_notes(self, notes: str) -> None:
        field = self.require("release_notes_input", "the What's New field")
        field.fill(notes)
        self.snapshot("release-notes")

    def submit_for_review(self, expected_version: str | None = None) -> None:
        button = self.require_enabled("submit_button", "the Publish button")
        button.click()
        confirm = self._first_visible("submit_confirm_button", timeout_ms=5_000)
        if confirm is not None:
            confirm.click()
        self.guard_human_gate("submit")

        # APKPure queues publishing for human review too, so a published
        # version does not become a normal table row -- waiting for one would
        # time out on a successful publish, exactly as it did on upload.
        pending = self._first_visible("publish_pending_marker", timeout_ms=60_000)
        if pending is not None:
            self.evidence.log(f"APKPure queued the publish: {(pending.inner_text() or '').strip()[:120]}")
            self.snapshot("publish-pending-review")
            return

        # Prefer a falsifiable check -- the version actually appearing in the
        # table -- over a status string. The console's flow diagram permanently
        # reads "Pending Approval", so text alone cannot prove anything.
        if expected_version and self._await_version_row(expected_version):
            self.snapshot("submitted")
            return
        if self._first_visible("submit_success_marker", timeout_ms=self.timeout_ms) is not None:
            self.snapshot("submitted")
            return

        self.snapshot("submit-unconfirmed")
        raise RemoteError(
            "Clicked Publish, but neither a review status nor a new version row appeared"
            + (f" for {expected_version}" if expected_version else "")
            + ". Check the console by hand before re-running: a blind retry may create a "
            "duplicate submission."
        )

    def _await_version_row(self, version: str, attempts: int = 10) -> bool:
        for _ in range(attempts):
            if version in self.published_version_names():
                return True
            self.page.wait_for_timeout(2_000)
        return False


class BrowserMode(str, Enum):
    """How the driver gets a browser.

    APKPure sits behind Cloudflare, which challenges Playwright's bundled
    Chromium. The answer is not to disguise the automation — this code will not
    spoof fingerprints or solve challenges — but to let a human drive a real
    browser through the challenge and have the automation work inside the
    browser they already trust.
    """

    #: Playwright's bundled Chromium plus a saved storage state. Fastest, and
    #: the most likely to be challenged.
    BUNDLED = "bundled"
    #: The real Google Chrome install, with a persistent profile directory that
    #: survives between runs, so Cloudflare sees a returning browser.
    CHROME = "chrome"
    #: Attach to a Chrome the human started with --remote-debugging-port and
    #: signed in themselves. Nothing about the session is synthesised.
    CDP = "cdp"


def resolve_browser_mode(configured: object, env: dict[str, str] | None = None) -> "BrowserMode":
    """Config value wins, then APKPURE_BROWSER, then the bundled default."""
    raw = configured or (env or {}).get("APKPURE_BROWSER") or BrowserMode.BUNDLED.value
    try:
        return BrowserMode(str(raw).strip().lower())
    except ValueError as exc:
        valid = ", ".join(mode.value for mode in BrowserMode)
        raise PreflightError(f"Unknown browser mode {raw!r}. Valid: {valid}") from exc


DEFAULT_PROFILE_DIR = Path.home() / ".config" / "airo" / "apkpure-chrome-profile"
DEFAULT_CDP_ENDPOINT = "http://127.0.0.1:9222"

#: Chromium-family browsers a user is likely to already have signed in. Any of
#: these can back the `chrome` mode via --browser-path; Playwright's `channel`
#: only knows about Google's own builds.
KNOWN_CHROMIUM_BROWSERS = {
    "arc": "/Applications/Arc.app/Contents/MacOS/Arc",
    "brave": "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    "chrome": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "edge": "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
}


LAUNCH_SERVICES_PLIST = (
    "Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
)


def default_browser_path() -> Path:
    """The executable of whichever browser handles https on this Mac.

    Read from LaunchServices rather than guessed, then resolved to a real
    binary by scanning app bundles for the matching identifier. Spotlight is
    not consulted: `mdfind` returns nothing when indexing is off.
    """
    if sys.platform != "darwin":
        raise PreflightError(
            "--browser-path default only resolves the system browser on macOS. "
            "Pass an explicit path, or one of: "
            + ", ".join(sorted(KNOWN_CHROMIUM_BROWSERS))
        )
    plist = Path.home() / LAUNCH_SERVICES_PLIST
    bundle_id = ""
    if plist.is_file():
        with contextlib.suppress(Exception):
            handlers = plistlib.loads(plist.read_bytes()).get("LSHandlers", [])
            for handler in handlers:
                if handler.get("LSHandlerURLScheme") == "https":
                    bundle_id = str(
                        handler.get("LSHandlerRoleAll")
                        or handler.get("LSHandlerRoleViewer")
                        or ""
                    ).lower()
                    break
    if not bundle_id:
        raise PreflightError(
            "Could not read the default browser from LaunchServices. Pass "
            "--browser-path with an explicit browser instead."
        )

    for root in (Path("/Applications"), Path.home() / "Applications"):
        if not root.is_dir():
            continue
        for app in sorted(root.glob("*.app")):
            info = app / "Contents" / "Info.plist"
            if not info.is_file():
                continue
            try:
                data = plistlib.loads(info.read_bytes())
            except Exception:  # noqa: BLE001 - a malformed bundle is not fatal
                continue
            if str(data.get("CFBundleIdentifier", "")).lower() != bundle_id:
                continue
            executable = app / "Contents" / "MacOS" / str(data.get("CFBundleExecutable", ""))
            if executable.is_file():
                return executable
    raise PreflightError(
        f"Default browser {bundle_id!r} is not an app bundle this tool can launch. "
        "Pass --browser-path with an explicit Chromium-family browser."
    )


#: Chromium forks that ship without the DevTools protocol. Arc launches
#: happily with --remote-debugging-port and then never opens the port, so the
#: only symptom is a connection refused several steps later.
BROWSERS_WITHOUT_CDP = {"arc"}


def supports_cdp(executable: Path | None) -> bool:
    return not (executable and executable.name.lower() in BROWSERS_WITHOUT_CDP)


def resolve_browser_path(value: object) -> Path | None:
    """Accept either a shorthand name (arc, brave, edge) or a full path."""
    if not value:
        return None
    raw = str(value).strip()
    if raw.lower() == "default":
        return default_browser_path()
    candidate = Path(KNOWN_CHROMIUM_BROWSERS.get(raw.lower(), raw)).expanduser()
    if not candidate.exists():
        known = ", ".join(sorted(KNOWN_CHROMIUM_BROWSERS))
        raise PreflightError(
            f"Browser executable not found: {candidate}. "
            f"Pass a full path, or one of: {known}."
        )
    return candidate


@contextlib.contextmanager
def console_session(
    *,
    storage_state: Path,
    evidence: EvidenceRecorder,
    selectors: SelectorSet,
    headless: bool = True,
    timeout_ms: int = 60_000,
    mode: BrowserMode = BrowserMode.BUNDLED,
    profile_dir: Path | None = None,
    cdp_endpoint: str = DEFAULT_CDP_ENDPOINT,
    browser_path: Path | None = None,
) -> Iterator[ConsoleSession]:
    """Open an APKPure console page using whichever browser `mode` selects."""
    sync_playwright = import_playwright()
    evidence.log(f"browser mode: {mode.value}")

    with sync_playwright() as playwright:
        if mode is BrowserMode.CDP:
            manager = _cdp_context(playwright, cdp_endpoint, evidence, browser_path)
        elif mode is BrowserMode.CHROME:
            manager = _persistent_chrome_context(
                playwright,
                profile_dir or DEFAULT_PROFILE_DIR,
                headless,
                evidence,
                browser_path,
            )
        else:
            manager = _bundled_context(playwright, storage_state, headless, evidence)

        with manager as (context, persist_storage_state):
            context.set_default_timeout(timeout_ms)
            page = context.pages[0] if context.pages else context.new_page()
            page.on("console", lambda msg: evidence.log(f"browser console [{msg.type}] {msg.text}"))
            try:
                yield ConsoleSession(
                    page=page, selectors=selectors, evidence=evidence, timeout_ms=timeout_ms
                )
            finally:
                if persist_storage_state:
                    # Refresh the stored session so a rolling cookie does not
                    # expire the automation between releases.
                    with contextlib.suppress(Exception):
                        context.storage_state(path=str(storage_state))


@contextlib.contextmanager
def _bundled_context(playwright, storage_state: Path, headless: bool, evidence: EvidenceRecorder):
    if not storage_state.is_file():
        raise CredentialError(
            f"No APKPure session state at {storage_state}. Run "
            "`python3 -m tools.publish login apkpure` on a machine with a display first."
        )
    browser = playwright.chromium.launch(headless=headless)
    try:
        context = browser.new_context(
            storage_state=str(storage_state),
            viewport=DEFAULT_VIEWPORT,
            accept_downloads=False,
        )
        try:
            yield context, True
        finally:
            context.close()
    finally:
        browser.close()


@contextlib.contextmanager
def _persistent_chrome_context(
    playwright,
    profile_dir: Path,
    headless: bool,
    evidence: EvidenceRecorder,
    executable_path: Path | None = None,
):
    """Real Chrome with a profile that persists between runs.

    No stealth flags and no fingerprint patching: this is a genuine Chrome with
    a genuine profile, which is simply a truer description of what is happening
    than a throwaway Chromium is.
    """
    profile_dir = profile_dir.expanduser()
    profile_dir.mkdir(parents=True, exist_ok=True)
    evidence.log(f"browser profile: {profile_dir}")
    launch: dict = {"channel": "chrome"} if executable_path is None else {
        "executable_path": str(executable_path)
    }
    evidence.log(f"launching {executable_path or 'channel=chrome'}")
    try:
        context = playwright.chromium.launch_persistent_context(
            str(profile_dir),
            headless=headless,
            viewport=DEFAULT_VIEWPORT,
            accept_downloads=False,
            **launch,
        )
    except Exception as exc:  # noqa: BLE001 - Playwright raises its own errors
        raise PreflightError(
            f"Could not start {executable_path or 'Google Chrome'} ({exc}). "
            "Pass --browser-path arc|brave|edge or a full path, or use "
            "--browser cdp to attach to a browser you started yourself."
        ) from exc
    try:
        yield context, False
    finally:
        with contextlib.suppress(Exception):
            context.close()


@contextlib.contextmanager
def _cdp_context(
    playwright,
    endpoint: str,
    evidence: EvidenceRecorder,
    browser_path: Path | None = None,
):
    """Attach to a Chrome the human already started and signed in.

    The human clears any Cloudflare or login challenge in their own browser.
    This process never sees a credential and never answers a challenge; it only
    drives a tab in a session that a human established.
    """
    evidence.log(f"attaching over CDP to {endpoint}")
    if not supports_cdp(browser_path):
        raise PreflightError(
            f"{browser_path.name} does not expose the DevTools protocol: it accepts "
            "--remote-debugging-port and then never opens the port, so this attach can "
            "only ever fail. Use a browser that does, for example:\n"
            "  --browser cdp --browser-path chrome\n"
            "You sign in to APKPure there once; it does not have to be your default browser."
        )
    try:
        browser = playwright.chromium.connect_over_cdp(endpoint)
    except Exception as exc:  # noqa: BLE001 - Playwright raises its own errors
        launcher = str(browser_path or "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
        raise PreflightError(
            f"Could not attach to a browser at {endpoint} ({exc}).\n"
            "Nothing is listening there. Start the browser with remote debugging first:\n"
            f"  '{launcher}' \\\n"
            "    --remote-debugging-port=9222 \\\n"
            "    --user-data-dir=\"$HOME/.config/airo/apkpure-chrome-profile\"\n"
            "then sign in to APKPure in that window and re-run this command.\n"
            "Note: Arc accepts the flag but never opens the port -- use Chrome or Brave."
        ) from exc
    context = browser.contexts[0] if browser.contexts else browser.new_context()
    try:
        yield context, False
    finally:
        # The human owns this browser: detach, never close it.
        with contextlib.suppress(Exception):
            browser.close()


def interactive_chrome_login(
    profile_dir: Path,
    evidence: EvidenceRecorder,
    confirm: Callable[[str], object] = input,
    executable_path: Path | None = None,
) -> Path:
    """Sign in inside a persistent real-Chrome profile.

    Nothing is exported: the cookies stay in Chrome's own profile directory and
    later runs reuse that same profile, so a Cloudflare challenge cleared by
    hand here stays cleared. Use this when the bundled Chromium is challenged.
    """
    sync_playwright = import_playwright()
    profile_dir = profile_dir.expanduser()
    profile_dir.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        try:
            launch: dict = {"channel": "chrome"} if executable_path is None else {
                "executable_path": str(executable_path)
            }
            context = playwright.chromium.launch_persistent_context(
                str(profile_dir), headless=False, viewport=DEFAULT_VIEWPORT, **launch
            )
        except Exception as exc:  # noqa: BLE001 - Playwright raises its own errors
            raise PreflightError(
                f"Could not start {executable_path or 'Google Chrome'} ({exc}). Pass "
                "--browser-path arc|brave|edge, or sign in with your own browser and "
                "use --browser cdp instead."
            ) from exc
        page = context.pages[0] if context.pages else context.new_page()
        page.goto(SIGN_IN_URL, wait_until="domcontentloaded")
        evidence.log(f"opened {SIGN_IN_URL} in persistent Chrome profile {profile_dir}")
        confirm(
            "\nSign in to APKPure in the browser window that just opened, clearing any\n"
            "Cloudflare check yourself. Then press Enter here to close it: "
        )
        with contextlib.suppress(Exception):
            context.close()
    evidence.log(f"chrome profile retained at {profile_dir}")
    return profile_dir


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
