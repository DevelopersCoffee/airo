# Aika Stream on Fire TV (Amazon Appstore)

Aika Stream ships on Fire OS from the same Dart entrypoint and TV pubspec as the
Google Play Android TV build (`lib/main_tv.dart`, `pubspec_tv.yaml`). The Fire
line is selected at build time with `--dart-define=APP_VARIANT=fireTv`, which
activates the Fire manifest and Gradle gates that omit Google Play services–only
features (Cast Connect receiver, AdMob, Android Auto metadata, Play Cast TV
native SDK).

**Package id:** `com.developerscoffee.tv.midas` (unchanged from Play TV).

## Supported devices

| Device class | Status |
| --- | --- |
| Fire TV Stick 4K Max (2nd gen), Fire TV Cube, earlier Fire OS sticks | Target (Android-based Fire OS) |
| Fire TV Stick 4K (3rd gen) and Fire TV 4K Select on **Vega OS** | **Unsupported** — Vega OS cannot install Android APKs or AABs. Do not sideload or publish Vega builds; there is no CI job or release artifact for Vega. |

## Local build

From the repo root:

```bash
scripts/build-fire-tv.sh --apk-only
```

Or manually:

```bash
cd app
cp pubspec_tv.yaml pubspec.yaml && flutter pub get
flutter build apk --release \
  --target=lib/main_tv.dart \
  --dart-define=APP_VARIANT=fireTv \
  --dart-define=APP_PLATFORM=androidTv \
  --target-platform=android-arm64
```

Typical release outputs (after `scripts/build-fire-tv.sh`):

| Artifact | Path |
| --- | --- |
| arm64 APK (CI parity) | `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| Convenience copy | `app/build/aika-stream-fire-arm64.apk` |
| Amazon Appstore AAB | `app/build/aika-stream-fire-amazon.aab` |

Configure signing via `app/android/key.properties` (see `key.properties.example`).
When no release keystore is present, `scripts/build-fire-tv.sh` mints a local
validation keystore (not for store upload).

### Play TV build (unchanged)

```bash
scripts/build-tv.sh --apk-only
```

Uses `--dart-define=APP_VARIANT=tv` and the Play TV manifest under
`app/android/app/src/tv/`.

## CI

The **`build-android`** job in `.github/workflows/ci.yml` includes a **`fire-tv`**
matrix leg. It mirrors the TV leg (same pubspec swap, size budget, mpv exclusion
check) but passes `APP_VARIANT=fireTv` and runs `scripts/check-fire-tv-release.sh`.

### Repository secrets (names only)

When all four are set, CI signs Fire artifacts with the Amazon release keystore.
If any secret is missing, the job still completes with an ephemeral debug-style
CI validation keystore (same pattern as the TV leg).

| Secret | Purpose |
| --- | --- |
| `FIRE_TV_RELEASE_KEYSTORE_BASE64` | Base64-encoded `.jks` / `.keystore` |
| `FIRE_TV_KEYSTORE_PASSWORD` | Keystore password |
| `FIRE_TV_KEY_ALIAS` | Signing key alias |
| `FIRE_TV_KEY_PASSWORD` | Key password |

Optional Firebase placeholders use the same TV CI pattern (`FIREBASE_OPTIONS_DART_B64`,
`GOOGLE_SERVICES_JSON`); Fire builds do not require Google Play services at runtime.

## Differences from the Play TV build

| Area | Play TV (`APP_VARIANT=tv`) | Fire TV (`APP_VARIANT=fireTv`) |
| --- | --- | --- |
| Manifest | `src/tv/AndroidManifest.xml` | `src/fireTv/AndroidManifest.xml` |
| Google Cast TV receiver SDK | Present (dev/test Cast Connect) | Omitted |
| AdMob / AD_ID | Declared; ads skipped on leanback | Removed from manifest; no AdMob init |
| Android Auto metadata | Present | Removed |
| ML Kit GenAI Prompt (Gemini Nano) | Gradle dependency | Omitted on Fire variant |
| Voice / IPTV intent assistant | Rule backend by default; optional native pack via `AIRO_MEDIA_PACK*` | **Rule backend only** — build scripts do not pass SLM pack defines; no bundled llama/SLM weights |
| Chromecast sender UI | Real controller on Android | Unavailable transport (no GMS crash) |
| Store URL for Aika Stream | Google Play | Amazon Appstore (`mas/dl/android?p=…`) |

RevenueCat / Play Billing: the open-source bootstrap still exposes
`NoEntitlements`; Fire builds do not add a billing SDK.

## Amazon Appstore submission (manual)

1. Build a signed AAB or APK with production Fire signing secrets configured locally or in CI.
2. Sign in to [Amazon Developer Console](https://developer.amazon.com/apps-and-games).
3. Create or open the Aika Stream app listing (`com.developerscoffee.tv.midas`).
4. Upload the binary under **Device support** → Fire TV.
5. Complete content rating, privacy, and screenshots (1080p TV captures).
6. Submit for review on the **Amazon Appstore** track (not Vega).

Internal QA may use a **Fire OS APK** built from CI or `scripts/build-fire-tv.sh`
with a known signing key; distribution stays within Amazon test channels or
maintainer-controlled install on registered Fire OS hardware.

## Verification

```bash
scripts/check-fire-tv-release.sh
bash -n scripts/build-fire-tv.sh
python3 scripts/check-build-profiles.py
```
