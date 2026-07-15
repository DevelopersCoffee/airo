# Legacy Store and Distribution Matrix

Issue: ATV-057
Package: `platform_certification`
Layer: Platform framework, consumed by Airo TV release workflows

## Purpose

Airo TV legacy receiver releases need a reusable distribution policy for Google
Play TV, Amazon Appstore, direct APK delivery, and operator boxes. The policy
must be deterministic so release automation can decide which channel claims are
allowed without hard-coding store rules in Airo TV product code.

This contract belongs in `platform_certification` because that package already
owns validation matrices, store-policy gates, physical-device evidence, and
device support claims.

## Channels

| Target id | Channel | Platform | Product profile | Required evidence |
| --- | --- | --- | --- | --- |
| `google-play-tv-android-tv` | `google_play_tv` | Android TV | Full TV | Play AAB, store listing, content rating, data safety, store policy review, physical-device evidence |
| `amazon-appstore-fire-tv` | `amazon_appstore` | Fire TV | Lite Receiver | APK, store listing, store policy review, legal review, remote-navigation evidence, physical-device evidence |
| `direct-apk-legacy-android-tv` | `direct_apk` | Android TV | Lite Receiver | APK, SHA256 sums, release manifest, package-content scan, legal review, physical-device evidence |
| `operator-box-legacy-receiver` | `operator_box` | Android TV | Lite Receiver | Operator approval, APK, release manifest, store/channel policy review, legal review, physical-device evidence |

## Rules

- Google Play TV cannot be claimed until the TV Play package, listing, content
  rating, data safety, store policy review, and physical TV evidence exist.
- Amazon Appstore / Fire TV cannot be claimed until Fire TV APK, listing,
  store policy review, legal review, remote-navigation evidence, and physical
  Fire TV evidence exist.
- Direct APK delivery cannot be claimed until APK, checksum, release manifest,
  package scan, legal review, and install/launch evidence exist.
- Operator boxes cannot be claimed until operator approval and channel-specific
  release evidence exist.
- Missing, stale, wrong-target, or wrong-kind evidence blocks support claims
  with stable codes.
- Public reports expose channel ids, target ids, statuses, evidence kinds, and
  blocker codes only.

## Non-Goals

This contract does not upload binaries, submit listings, manage signing,
configure store accounts, collect evidence, or render release UI.

## Automation

- Unit tests assert all four channel targets and their required evidence.
- Evaluation tests cover complete evidence, missing evidence, wrong-target
  evidence, stale evidence, and public-map redaction.
- Package checks run with `flutter test` and `flutter analyze --fatal-infos`
  from `packages/platform_certification`.
