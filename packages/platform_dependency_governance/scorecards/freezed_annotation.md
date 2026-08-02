# Scorecard — `freezed_annotation`

| Field | Value |
|---|---|
| `schemaVersion` | 1 |
| `packageName` | `freezed_annotation` |
| `version` | 3.1.0 |
| `usedByModule` | `feature_mind` |
| `importance` | `required` |
| `minimumAndroidApi` | n/a — pure Dart |
| `hasNativeCode` | false |
| `nativeArchitectures` | none |
| `estimatedBinarySizeKb` | <10 — annotations and a small runtime |
| `estimatedRuntimeMemoryMb` | negligible |
| `hasBackgroundBehavior` | false |
| `backgroundBehavior` | n/a |
| `hasLegacyKotlinGradlePluginRisk` | false |
| `requiresShrinkerRules` | false |
| `shrinkerRulesValidated` | n/a |
| `tvIssuesReviewed` | true |
| `hasFallbackOrStub` | n/a |
| `maintenanceOwner` | Product Manager (`feature_mind` `module.yaml`) |

## Licence

MIT.

## Why this dependency

The runtime half of [`freezed`](freezed.md). Unlike the generator it **does**
ship, because the generated sealed classes reference it. Separated from the
generator by design, so the tool stays out of the app.

## Blockers

**None.** Pure Dart, negligible size, no platform behaviour.

## Risk

Tracks `freezed`. Upgrade the two together; a mismatch is a generation-time
failure, not a run-time one.
