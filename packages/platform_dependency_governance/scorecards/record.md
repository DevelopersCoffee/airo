# Scorecard — `record`

| Field | Value |
|---|---|
| `schemaVersion` | 1 |
| `packageName` | `record` |
| `version` | 6.2.1 |
| `usedByModule` | `feature_mind` |
| `importance` | `required` |
| `minimumAndroidApi` | 23 (`record_android` 1.5.2) |
| `hasNativeCode` | true |
| `nativeArchitectures` | `arm64`, `armeabi_v7a`, `x64`, `x86` |
| `estimatedBinarySizeKb` | ~240 (platform sources; no bundled `.so`) |
| `estimatedRuntimeMemoryMb` | <5 — a 16 kHz mono PCM ring buffer |
| `hasBackgroundBehavior` | true |
| `backgroundBehavior` | Holds an audio session while recording. Stops on `stop()`/`dispose()`; no scheduled work, no wake locks, no push. |
| `hasLegacyKotlinGradlePluginRisk` | false |
| `requiresShrinkerRules` | false |
| `shrinkerRulesValidated` | n/a |
| `tvIssuesReviewed` | true — see below |
| `hasFallbackOrStub` | true — `MindUnavailable.bridgeMissing` covers a platform with no capture |
| `maintenanceOwner` | Product Manager (`feature_mind` `module.yaml`) |

## Licence

BSD-3-Clause. Permissive, no copyleft obligation, no attribution burden beyond
retaining the notice.

## Why this dependency

Step 1 of the Milestone 2 journey is *record*. Nothing else in the workspace
captures audio, and the alternative is a platform channel per OS — the same
native surface with none of the maintenance.

It is configured to emit exactly what the speech engine wants: **16 kHz mono
16-bit PCM WAV**. That is the whole reason to prefer a capture library over a
hand-rolled channel: asking the platform for the right format costs nothing,
while converting afterwards would mean resampling in Dart on the main isolate.

## Blockers

**None.**

- `raises_android_api_floor` — does not apply. `minSdk 23` is *below* Airo's API
  26 baseline, so it constrains nothing.
- `background_behavior_undeclared` — declared above.
- `missing_native_architectures` — all four are covered.

## TV review

Airo TV does not record. `feature_mind` is not in `pubspec_tv.yaml`, so the
dependency never reaches a TV build — flavors are separate pubspecs, and a
dependency added to one is invisible to the others.

## Risk

Community-maintained rather than first-party. The exposure is bounded: the only
call sites are `MindService.startRecording` / `stopRecording`, and the output is
a WAV file that `crate::wav` parses independently. Replacing it would touch one
file.

Version pinned by `pubspec.lock`; 7.x is available and deferred rather than
taken blind — an upgrade is a re-review, not a bump.
