---
name: shipping-aika-stream-play
description: >-
  Ship Aika Stream (com.developerscoffee.tv.midas) to Google Play Internal
  then Production. Use when bumping pubspec_tv.yaml, building a Play AAB/OBB,
  uploading or promoting on Play Console, cutting release/aika-stream-v*, or
  when the user says Play, OBB, versionCode, Internal testing, or production
  listing.
---

# Shipping Aika Stream to Play

Read `docs/okf/aika-stream-play/index.md`, then
`docs/okf/aika-stream-play/playbooks/shipping-play-drop.md`, before acting.
Invariants live in `.cursor/rules/aika-stream-play-ship.mdc` (load-on-demand,
not always-on).

## Sequence

1. New worktree from `origin/main`. Do not merge leftover IPTV worktrees.
2. Read Internal **and** Production Latest. Next `versionCode` is unused
   on both. Do not bump until this drop ships. Do not re-upload a live code.
3. Edit only `app/pubspec_tv.yaml`, then
   `scripts/aika_stream_version.sh --sync-stub`.
4. Confirm `app/android/release.keystore` and
   `key.properties` `storeFile=release.keystore`. Kill any
   `build-tv.sh` run that starts minting `tv-validation`.
5. Build:

   ```bash
   GRADLE_USER_HOME="$HOME/.gradle" \
     bash scripts/build-tv.sh --aab-only --build-name <name> --build-number <code>
   ```

   Flags are space-separated. Copy to
   `~/Downloads/Aika-Stream-<name>-<code>.aab` and record SHA-256.
6. Human uploads (Play service-account JSON is not in GitHub secrets).
   Agent publishes Internal, then Production. If Production shows **Save**
   not **Save and publish**, use Publishing overview → Send for review.
7. Live = Production track Latest, not "in review". Then
   `release/aika-stream-v<versionName>` from the SHA that built that AAB.

Play dart-defines stay unset. `[skip ci]` only on non-executable files.
Sideload must be uninstalled before a Play install.
