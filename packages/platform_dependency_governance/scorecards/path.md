# Scorecard — `path`

| Field | Value |
|---|---|
| `schemaVersion` | 1 |
| `packageName` | `path` |
| `version` | 1.9.1 |
| `usedByModule` | `feature_mind` |
| `importance` | `required` |
| `minimumAndroidApi` | n/a — pure Dart |
| `hasNativeCode` | false |
| `nativeArchitectures` | none |
| `estimatedBinarySizeKb` | <20 |
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

BSD-3-Clause, copyright the Dart project authors. First-party, shipped by the
Dart team.

## Why this dependency

Joining paths with string interpolation is correct until it meets Windows, and
`feature_mind` declares Windows. `p.join` and `p.normalize` are the two calls
used.

## Blockers

**None.** Pure Dart, first-party, already transitively present through
`path_provider` and most of the workspace.
