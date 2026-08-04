"""APKPure Developer Console selectors.

APKPure publishes no upload API, so this is browser automation against a DOM
nobody controls but APKPure. Every selector below is therefore:

* a *list* of candidates tried in order, so a markup change breaks one candidate
  rather than the whole publisher;
* overridable at runtime from a JSON file via ``APKPURE_SELECTORS_FILE``, so a
  broken release can be unblocked without a code change and a PR.

**Status: recorded against the live console on 2026-08-04** for
io.airo.app.tv, signed in, via CDP. The navigation, upload-form, release-notes,
and publish selectors were read off the real DOM. Three could not be recorded
because they only appear mid-upload -- ``upload_complete_marker``,
``upload_error_marker`` and ``submit_success_marker`` remain heuristics, and the
first real upload should confirm them.

Re-record after any console redesign with

    python3 -m tools.publish doctor apkpure --browser cdp --browser-path chrome

"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

CONSOLE_ORIGIN = "https://developer.apkpure.com"
SIGN_IN_URL = f"{CONSOLE_ORIGIN}/login"
CONSOLE_URL_TEMPLATE = f"{CONSOLE_ORIGIN}/console/{{package_id}}"

#: Logical step -> ordered candidate selectors. Playwright selector syntax;
#: ``text=`` and ``role=`` engines are allowed and preferred over brittle
#: class-name chains.
#: Logical step -> ordered candidate selectors, tried in order.
#:
#: Recorded against the live console on 2026-08-04 for io.airo.app.tv. The
#: console is a Materialize CSS app: the version table and the upload form both
#: live on /console/<package>/versions, and there is no separate "new version"
#: dialog. Ids (#file, #textarea1) come first because they are what the page
#: actually uses; the text-based candidates are fallbacks for a redesign.
DEFAULT_SELECTORS: dict[str, list[str]] = {
    # Sidebar entry present on every signed-in console page. The Logout links
    # exist too but live in a collapsed dropdown, so they are never visible and
    # cannot serve as the marker.
    "signed_in_marker": [
        "a:has-text('Manage Apps')",
        "a:has-text('MANAGE VERSIONS')",
        "a:has-text('APP DETAILS')",
    ],
    "sign_in_marker": [
        "form[action*='login']",
        "input[type='password']",
        ":text-matches('^(Sign in|Log in)$', 'i')",
    ],
    "manage_versions_link": [
        "a:has-text('MANAGE VERSIONS')",
        "a[href$='/versions']",
    ],
    # There is no separate dialog: the upload form is rendered directly on the
    # versions page. open_upload_form() treats this as optional and continues.
    "new_version_button": [
        "a:has-text('Upload .APK File')",
    ],
    "apk_file_input": [
        "input#file",
        "input[type='file'][accept*='apk']",
        "input[type='file']",
    ],
    "upload_complete_marker": [
        "[data-testid='upload-complete']",
        ":text-matches('(Upload (complete|success)|100%)', 'i')",
    ],
    "upload_error_marker": [
        ".toast :text-matches('(failed|invalid|error)', 'i')",
        "[role='alert']",
        ":text-matches('(upload failed|invalid apk|signature mismatch)', 'i')",
    ],
    "release_notes_input": [
        "textarea#textarea1",
        "textarea[name*='whatsnew' i]",
        "textarea[name*='release' i]",
    ],
    # PUBLISH is an anchor, not a button, and sits next to an identically
    # styled VIEW ON APKPURE link -- so match on the text, never the class.
    "submit_button": [
        "a:has-text('PUBLISH')",
        "button:has-text('Publish')",
    ],
    # Deliberately narrow. The only modal on this page is the *delete* confirm
    # ("Yes,delete it!"), so a loose confirm selector here would click destroy
    # instead of publish. Nothing generic, and never .modal-action alone.
    "submit_confirm_button": [
        "a.modal-action:has-text('Yes, publish')",
        ".modal.open a:has-text('Publish')",
        ".modal.open button:has-text('Confirm')",
    ],
    # ".step-name" is excluded deliberately: step 4 of the static flow diagram
    # is literally the text "Pending Approval", so an unscoped match reports
    # success on an idle page that has published nothing.
    "submit_success_marker": [
        ":text-matches('(in review|under review|submitted)', 'i'):not(.step-name)",
        "[data-testid='review-status']",
    ],
    # Version rows only. The table also holds collapsed detail rows (signature,
    # SHA1, architecture) that are present but never visible.
    "version_row": [
        "table tbody tr:visible",
        "[data-testid='version-row']",
    ],
    "human_gate_marker": [
        "iframe[src*='recaptcha']",
        "iframe[src*='hcaptcha']",
        "iframe[title*='challenge' i]",
        ":text-matches('(verification code|two-factor|2FA|captcha)', 'i')",
    ],
}


@dataclass(frozen=True)
class SelectorSet:
    """Resolved selector candidates, defaults merged with any override file."""

    mapping: dict[str, list[str]] = field(default_factory=lambda: dict(DEFAULT_SELECTORS))
    source: str = "defaults"

    @classmethod
    def load(cls, override_path: str | os.PathLike[str] | None = None) -> "SelectorSet":
        path_value = override_path or os.environ.get("APKPURE_SELECTORS_FILE", "")
        if not path_value:
            return cls()
        path = Path(path_value).expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"APKPure selector override file not found: {path}")
        data: Any = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError(f"APKPure selector override must be a JSON object: {path}")
        merged = {key: list(value) for key, value in DEFAULT_SELECTORS.items()}
        for key, value in data.items():
            if isinstance(value, str):
                merged[key] = [value]
            elif isinstance(value, list) and all(isinstance(item, str) for item in value):
                merged[key] = list(value)
            else:
                raise ValueError(
                    f"APKPure selector override '{key}' must be a string or list of strings"
                )
        return cls(mapping=merged, source=str(path))

    def candidates(self, key: str) -> list[str]:
        if key not in self.mapping:
            raise KeyError(f"Unknown APKPure selector key: {key}")
        return self.mapping[key]

    def keys(self) -> list[str]:
        return sorted(self.mapping)


def console_url(package_id: str) -> str:
    return CONSOLE_URL_TEMPLATE.format(package_id=package_id)
