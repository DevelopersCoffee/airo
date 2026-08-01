# Scorecard — `path_provider`

| Field | Value |
|---|---|
| `schemaVersion` | 1 |
| `packageName` | `path_provider` |
| `version` | 2.1.6 |
| `usedByModule` | `feature_mind` |
| `importance` | `required` |
| `minimumAndroidApi` | 21 |
| `hasNativeCode` | true (thin platform shims) |
| `nativeArchitectures` | `arm64`, `armeabi_v7a`, `x64`, `x86` |
| `estimatedBinarySizeKb` | <50 |
| `estimatedRuntimeMemoryMb` | negligible |
| `hasBackgroundBehavior` | false |
| `backgroundBehavior` | n/a |
| `hasLegacyKotlinGradlePluginRisk` | false |
| `requiresShrinkerRules` | false |
| `shrinkerRulesValidated` | n/a |
| `tvIssuesReviewed` | true |
| `hasFallbackOrStub` | n/a — no supported platform lacks it |
| `maintenanceOwner` | Product Manager (`feature_mind` `module.yaml`) |

## Licence

BSD-3-Clause, copyright The Flutter Authors. First-party, maintained in the
`flutter/packages` repository on the Flutter release cadence.

## Why this dependency

The application-support directory is the only correct home for the models and
the meeting log, and its location differs on every platform. Hardcoding it is
wrong on all five.

Application support rather than documents on purpose: these are not the user's
files, and on iOS the documents directory is user-visible.

## Blockers

**None.** First-party, no background behaviour, negligible size.

## Risk

As close to zero as a dependency gets. It is already an indirect dependency of
much of the workspace.
