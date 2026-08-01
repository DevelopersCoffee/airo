# Dependency scorecards

Constitution §6 requires a scorecard before a new dependency lands. The fields
below mirror `AiroDependencyAuditRecord` in
[`lib/src/dependency_governance_models.dart`](../lib/src/dependency_governance_models.dart)
so a scorecard can be lifted into a record without re-deciding what a field
means. Blocker codes are `AiroDependencyBlockerCode`'s stable ids.

One file per package. A federated plugin gets **one** scorecard covering its
platform implementations, because they version together and are never selected
independently.

| Scorecard | Used by | Importance |
|---|---|---|
| [record](record.md) | `feature_mind` | required |
| [path_provider](path_provider.md) | `feature_mind` | required |
| [path](path.md) | `feature_mind` | required |
| [freezed](freezed.md) | `feature_mind` | development_only |
| [freezed_annotation](freezed_annotation.md) | `feature_mind` | required |
