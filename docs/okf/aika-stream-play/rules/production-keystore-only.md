---
type: Rule
title: Production keystore only
description: Play AABs for com.developerscoffee.tv.midas must be signed with app/android/release.keystore, never the tv-validation key scripts/build-tv.sh may mint.
tags: [aika-stream, play-store, signing]
status: stable
generated: { by: cursor-grok-4.6/shipping-aika-stream-play, at: 2026-09-28T07:15:00Z }
verified: { by: human:Developers, at: 2026-09-28T07:15:00Z }
sources:
  - id: build-tv
    resource: /scripts/build-tv.sh
    description: Creates a local tv-validation keystore when release.keystore is missing.
---

# Production keystore only

Play listing `com.developerscoffee.tv.midas` accepts only the upload
certificate from `app/android/release.keystore`.

Before `scripts/build-tv.sh --aab-only`:

1. Confirm `app/android/release.keystore` exists in **this** worktree.
2. Confirm `app/android/key.properties` has `storeFile=release.keystore`
   (not a validation filename).
3. If either is missing, copy from a previous production-signed worktree.
   Do not let `build-tv.sh` create `tv-validation`. Kill that process if
   it already started.

A validation-signed AAB will fail Play upload. Do not "just try it".
