"""APKPure Developer Console selectors.

APKPure publishes no upload API, so this is browser automation against a DOM
nobody controls but APKPure. Every selector below is therefore:

* a *list* of candidates tried in order, so a markup change breaks one candidate
  rather than the whole publisher;
* overridable at runtime from a JSON file via ``APKPURE_SELECTORS_FILE``, so a
  broken release can be unblocked without a code change and a PR.

**Status: UNVERIFIED.** These candidates are written against the documented
console flow (sign in -> app -> Manage Versions -> upload APK -> what's new ->
submit) but have not been recorded against the live DOM. Run

    python3 -m tools.publish doctor apkpure --profile tv

to dump the real page and replace them. Until that dump exists, treat a
successful run as unproven.
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
DEFAULT_SELECTORS: dict[str, list[str]] = {
    # Proof that the stored session is still valid.
    "signed_in_marker": [
        "[data-testid='user-menu']",
        "header :text-matches('(Sign out|Log out|Logout)', 'i')",
        "a[href*='/console/']",
    ],
    # Shown when the session has expired and a human must re-authenticate.
    "sign_in_marker": [
        "form[action*='login']",
        "input[type='password']",
        ":text-matches('^(Sign in|Log in)$', 'i')",
    ],
    "manage_versions_link": [
        "a:has-text('Manage Versions')",
        "a:has-text('Versions')",
        "[data-testid='manage-versions']",
    ],
    "new_version_button": [
        "button:has-text('Upload APK')",
        "button:has-text('New Version')",
        "button:has-text('Add Version')",
    ],
    # The <input type=file>; Playwright sets files on it directly, no OS dialog.
    "apk_file_input": [
        "input[type='file'][accept*='apk']",
        "input[type='file']",
    ],
    "upload_complete_marker": [
        "[data-testid='upload-complete']",
        ":text-matches('(Upload (complete|success)|100%)', 'i')",
    ],
    "upload_error_marker": [
        "[role='alert']",
        ".ant-message-error",
        ":text-matches('(upload failed|invalid apk|signature mismatch)', 'i')",
    ],
    "release_notes_input": [
        "textarea[name*='whatsnew' i]",
        "textarea[name*='release' i]",
        "textarea[placeholder*=\"What's New\" i]",
        "textarea",
    ],
    "submit_button": [
        "button:has-text('Submit for Review')",
        "button:has-text('Submit')",
        "button[type='submit']",
    ],
    "submit_confirm_button": [
        "button:has-text('Confirm')",
        "button:has-text('OK')",
        ".ant-modal button:has-text('Submit')",
    ],
    "submit_success_marker": [
        ":text-matches('(in review|under review|submitted)', 'i')",
        "[data-testid='review-status']",
    ],
    # Rows in the versions table, used to detect an already-published version.
    "version_row": [
        "table tbody tr",
        "[data-testid='version-row']",
    ],
    # Anything that means a human has to take over: captcha, 2FA, device check.
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
