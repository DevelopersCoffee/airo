"""Stores Airo does not automate yet.

Each one records the real submission steps and reports BLOCKED, so a release run
can never report a store as published when a human still has to click through a
console. Promote one to a real publisher by replacing its class here once the
upload path is proven by hand at least once.
"""

from __future__ import annotations

from typing import ClassVar

from .base import ManualPublisher


class AmazonAppstorePublisher(ManualPublisher):
    """Amazon has a Developer Services API; wire it once an account exists.

    See https://developer.amazon.com/docs/app-submission-api/overview.html —
    it needs a client id/secret, and the edit/commit lifecycle is transactional,
    so a real publisher here is a genuine API integration rather than browser work.
    """

    name: ClassVar[str] = "amazon"
    description: ClassVar[str] = "Amazon Appstore (manual until Developer Services API is wired)"
    console_url: ClassVar[str] = "https://developer.amazon.com/apps-and-games/console/apps/list"
    checklist: ClassVar[tuple[str, ...]] = (
        "Open the Amazon Developer Console and select the Airo TV app.",
        "Create a new upcoming version and set the version name and code from the artifact table above.",
        "Upload the APK and wait for the binary checks to pass.",
        "Paste the release notes into 'Release notes for this version'.",
        "Confirm the Fire TV device support list still matches the qualification evidence.",
        "Submit for review and record the submission id in the release issue.",
    )


class HuaweiAppGalleryPublisher(ManualPublisher):
    """AppGallery Connect has a Publishing API worth wiring before Amazon.

    https://developer.huawei.com/consumer/en/doc/AppGallery-connect-References/agcapi-getstarted
    Needs a client id/secret pair and a two-step upload-url + commit flow.
    """

    name: ClassVar[str] = "huawei"
    description: ClassVar[str] = "Huawei AppGallery (manual until the Publishing API is wired)"
    console_url: ClassVar[str] = "https://developer.huawei.com/consumer/en/service/josp/agc/index.html"
    checklist: ClassVar[tuple[str, ...]] = (
        "Open AppGallery Connect and select the Airo TV app.",
        "Create a new version, then upload the APK under Software Version.",
        "Paste the release notes into 'New features'.",
        "Re-confirm the privacy policy URL and data-collection answers.",
        "Submit for review and record the submission id in the release issue.",
    )


class FDroidPublisher(ManualPublisher):
    """F-Droid builds from source; there is nothing to upload.

    The work is a metadata merge request against fdroiddata plus a reproducible
    build recipe, which is a source-side contract rather than a release step.
    """

    name: ClassVar[str] = "fdroid"
    description: ClassVar[str] = "F-Droid (source-built; metadata merge request, not an upload)"
    console_url: ClassVar[str] = "https://gitlab.com/fdroid/fdroiddata"
    checklist: ClassVar[tuple[str, ...]] = (
        "Confirm the release tag is signed and reachable from a public branch.",
        "Update the app metadata YAML in fdroiddata with the new versionName/versionCode.",
        "Confirm the build recipe still resolves every dependency without prebuilt binaries.",
        "Open the fdroiddata merge request and link it from the release issue.",
    )
