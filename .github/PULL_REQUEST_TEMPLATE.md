## Summary

<!-- What changed and why? -->

## Test Plan

- [ ] `flutter analyze` or relevant package analyzer passed
- [ ] `flutter test` or relevant package tests passed
- [ ] CI-only change validated with local script/YAML checks
- [ ] Manual device/simulator verification documented, or not applicable

## Agent Policy

- [ ] Linked issue includes a Critical Agent Gate.
- [ ] Linked issue includes a Feature Packet or documents why one is not needed.
- [ ] Cross-agent contract is documented for framework/application boundary work.
- [ ] Deterministic use cases and automation flows are linked or included.
- [ ] AI/tool/memory/routine changes include eval, trace, and redaction coverage.

## User-Facing Documentation

Every PR must keep the Airo public capability wiki accurate.

- [ ] I updated `docs/wiki` for any user-visible feature, route, platform,
      install, AI/model, privacy, file-type, media, game, finance, or
      troubleshooting change.
- [ ] No `docs/wiki` update is needed because this PR has no user-visible
      behavior or documentation impact.

## Plugin and Size Impact

- [ ] This PR adds new dependencies
- [ ] This PR adds or grows app/packages/plugins code
- [ ] Size impact is documented below
- [ ] Any module over 3 MB is a plugin or has an explicit plugin marker
- [ ] Any plugin over 5 MB has cache-management documentation

Size impact / plugin justification:

<!-- Example: packages/feature_x adds 1.4 MB source footprint and remains bundled because ... -->

## Checklist

- [ ] Code is formatted.
- [ ] Tests or manual verification are included above.
- [ ] Sensitive data, credentials, and signing artifacts are not committed.

## Release Notes

- [ ] User-facing change documented, or not applicable
