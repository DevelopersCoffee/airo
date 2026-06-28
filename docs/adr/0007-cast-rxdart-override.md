# ADR-0007: Keep Cast V1 rxdart Override

## Status

Accepted

## Date

2026-06-29

## Context

IPTV Google Cast V1 uses `flutter_chrome_cast` `^1.4.6` to provide Android and
iOS sender integration. That package requires `rxdart ^0.28.0`.

The existing Airo lint stack uses `custom_lint 0.6.4` and `riverpod_lint 2.3.10`.
Those packages resolve through `custom_lint` components that require
`rxdart ^0.27.7`. Without an override, Pub cannot solve the graph.

Dry-run checks showed that a minimal lint-stack upgrade is not isolated: it
cascades into analyzer, build_runner, riverpod_generator, macros, freezed, and
uuid constraints. Removing the lint stack would also be a broader tooling
change because `app/analysis_options.yaml` enables the `custom_lint` plugin.

## Decision

Keep the existing lint stack and add a bounded `dependency_overrides` entry for
`rxdart: ^0.28.0` in the Flutter app while Cast V1 is integrated.

This keeps the runtime Cast adapter on the planned package version, preserves
existing project lint tooling, and avoids a broad generator/analyzer migration
inside the Cast feature.

## Consequences

### Positive

- Cast V1 can use the current `flutter_chrome_cast` package.
- Existing `custom_lint` and `riverpod_lint` tooling remains configured.
- The dependency change is limited to `rxdart` instead of a full analyzer and
  code-generation stack migration.

### Negative

- The app carries an explicit dependency override.
- Future lint or generator upgrades must revisit this override.

### Risks

- `custom_lint` `0.6.4` was not authored with `rxdart 0.28.0` as its declared
  dependency range, so custom lint execution needs validation in CI.
- A future package update may make the override unnecessary or unsafe.

## Alternatives Considered

### Remove custom lint tooling

Rejected. This removes existing lint coverage and leaves
`app/analysis_options.yaml` inconsistent unless analyzer configuration is also
changed. That is a separate tooling decision, not part of Cast V1.

### Upgrade custom_lint and riverpod_lint

Rejected for this feature. Dry-run dependency resolution cascaded into analyzer,
build_runner, riverpod_generator, macros, freezed, and uuid constraints.

### Use an older flutter_chrome_cast version

Rejected. Available `flutter_chrome_cast` versions in the investigated range
still require `rxdart ^0.28.0`, and the V1 implementation plan selected
`^1.4.6`.

## Related Decisions

- [ADR-0001](0001-package-structure.md) - Package structure

## References

- [IPTV Google Cast V1 implementation plan](../superpowers/plans/2026-06-29-iptv-google-cast-v1.md)
- [flutter_chrome_cast package](https://pub.dev/packages/flutter_chrome_cast)
