#!/usr/bin/env python3
"""Tests for canonical Airo TV release APK resolution."""

from __future__ import annotations

import unittest

from resolve_release_tv_apk import resolve_canonical_tv_apk


class ResolveReleaseTvApkTest(unittest.TestCase):
    def test_selects_canonical_apk_from_current_release_assets(self) -> None:
        self.assertEqual(
            resolve_canonical_tv_apk(
                [
                    "Airo-TV-0.0.6-rc.1-arm64-v8a.apk",
                    "Airo-TV-0.0.6-rc.1-armeabi-v7a.apk",
                    "Airo-TV-0.0.6-rc.1-x86_64.apk",
                    "Airo-TV-0.0.6-rc.1.apk",
                    "Airo-TV-0.0.6-rc.1-Play-Store.aab",
                ]
            ),
            "Airo-TV-0.0.6-rc.1.apk",
        )

    def test_rejects_release_without_canonical_apk(self) -> None:
        with self.assertRaisesRegex(ValueError, "found 0"):
            resolve_canonical_tv_apk(["Airo-TV-0.0.6-rc.1-arm64-v8a.apk"])

    def test_rejects_ambiguous_canonical_apks(self) -> None:
        with self.assertRaisesRegex(ValueError, "found 2"):
            resolve_canonical_tv_apk(
                ["Airo-TV-0.0.5.apk", "Airo-TV-0.0.6-rc.1.apk"]
            )


if __name__ == "__main__":
    unittest.main()
