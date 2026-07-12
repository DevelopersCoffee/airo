# Lean build profiles

V2 edge-device builds are controlled by the platform build profile contract in
`.github/airo-build-profiles.json`.

Agents and release scripts must use that contract as the source of truth for:

- entrypoint
- app variant and platform dart-defines
- app id
- profile pubspec
- shared dependency constraints
- feature modules
- allowed native plugins
- heavy dependency stubs and overrides
- asset allowlist
- release and debug size budgets

Validate the contract before changing a variant pubspec or Android build matrix:

```bash
scripts/check-build-profiles.py
scripts/test-check-build-profiles.sh
scripts/check-variant-pubspecs.sh
```

The CI Android matrix builds the profile ids declared for CI, publishes an APK
size report for each profile, and fails enforced edge profiles when their
release APK exceeds the profile budget or the approved baseline growth limit.

Current enforced edge profiles:

- `iptv-standalone`
- `mobile-streaming`
- `tv`

`mobile-full` remains report-only because it is the v1 monolith line.
`web-validation` remains report-only because it validates browser UI/data flow,
not an installable edge APK.
