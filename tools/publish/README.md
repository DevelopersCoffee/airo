# Airo publishing framework

One release manifest in, one `Publisher` interface out. Every store — GitHub
Releases, Google Play, APKPure, Amazon, Huawei, F-Droid, the docs site — reads
the **same** `Release-Manifest.json` that `scripts/generate-release-manifest.py`
already produces, so no store upload can ever describe bytes that were not built
and hashed by the release workflow.

**Publishing never builds.** Artifacts always come from a published GitHub
Release, so a store and the release page cannot disagree about what shipped.

```
GitHub Release (v0.0.6)  →  gh release download  →  Release-Manifest.json + assets
                                              │
                                              ▼
                              tools/publish (verify → select → publish)
                                              │
        ┌────────────┬────────────┬───────────┼───────────┬───────────┐
        ▼            ▼            ▼           ▼           ▼           ▼
     github        play        apkpure      amazon      huawei      website
   (gh CLI)   (fastlane)   (Playwright)   (manual)    (manual)     (JSON)
```

## Why Python

`scripts/` is already the home of Airo's release automation and it is Python.
Playwright ships first-class Python bindings, so the APKPure leg needs no Node
toolchain in a Flutter/Melos repo. A Rust `Publisher` trait was the original
sketch, but `packages/core_native` still has no build wiring into the app, so a
Rust binary would have added a toolchain before it added a release.

## Commands

```bash
python3 -m tools.publish targets
```

```bash
python3 -m tools.publish fetch --tag v0.0.6
```

```bash
python3 -m tools.publish plan --tag v0.0.6 --profile tv --target apkpure
```

```bash
python3 -m tools.publish run --tag v0.0.6 --profile tv --target apkpure
```

`--tag` downloads the release into `build/release-artifacts/` and resolves the
manifest. Tags are v-prefixed (`v0.0.6`); manifest versions are not (`0.0.6`).
`--manifest` still accepts an already-downloaded directory.

`run` verifies every selected artifact's size and SHA-256 against the manifest
before it contacts anything. A mismatch aborts the run.

### Several manifests per tag

An orchestrated release carries both per-leg manifests (`Airo-TV-…`) and a
combined one (`Airo-…`). `fetch` indexes every manifest under each profile it
covers and picks the one describing **more** of that profile's artifacts — a
manifest that omits an artifact would silently omit it from the upload. Pass
`--profile` when a tag carries more than one profile.

### Do not select a single APK on `abi`

A TV release ships `Airo-TV-<v>.apk` (universal) alongside
`Airo-TV-<v>-arm64-v8a.apk`, and both legitimately carry `abi: android-arm64` —
no `abi` selector can tell them apart. Store selectors that need one exact file
therefore use `filenamePattern`:

```jsonc
"filenamePattern": "^Airo-TV-{version}\\.apk$"
```

Note that `Airo-TV-0.0.6-Release-Manifest.json` as published mislabels the
armeabi-v7a and x86_64 APKs as `android-arm64`. That generator bug is fixed on
main, but manifests already attached to older releases keep the wrong values —
another reason store selection does not read the field.

### Submit gating

`run` uploads and stages, but does **not** perform the irreversible store
submission unless `--submit` is passed. Without it:

| Target | Without `--submit` | With `--submit` |
| --- | --- | --- |
| `github` | uploads assets (reversible) | same |
| `play` | writes the plan, status `staged` | `fastlane supply` runs |
| `apkpure` | APK uploaded, notes filled, **not submitted** | Submit for Review clicked |
| `website` | writes the JSON | same |

`--dry-run` overrides `--submit` and contacts nothing at all. It also skips the
credential and binary preflight, so a release can be planned from a laptop that
cannot publish one.

### Exit codes

| Code | Meaning |
| --- | --- |
| 0 | every target succeeded, was skipped, staged, or dry-ran |
| 1 | at least one target failed |
| 2 | at least one target was blocked (preflight, or a manual-only store) — also the manifest-error code from the CLI wrapper |

## Configuration

`.github/airo-publish-targets.json` decides which stores exist and what each one
gets. Adding a listing is a config change, not a code change.

```jsonc
"apkpure": {
  "enabled": false,
  "profiles": {
    "tv": {
      "packageId": "io.airo.app.tv",
      "artifactSelector": {
        "artifactType": ["apk"],
        "filenamePattern": "^Airo-TV-{version}\\.apk$",
        "minCount": 1,
        "maxCount": 1
      },
      "releaseNotes": {
        "source": "changelog",
        "path": "CHANGELOG.md",
        "headingPattern": "^##\\s+v{version}\\b.*$",
        "maxChars": 4000,
        "fallback": "Bug fixes and stability improvements."
      },
      "options": { "headless": true }
    }
  }
}
```

- `artifactSelector` — declarative, over `artifactType`, `abi`,
  `distributionChannel`, `filenameContains`, `filenameExcludes`, and
  `filenamePattern` (regex, with `{version}` substituted). `maxCount: 1` is what
  stops "which APK did we upload?" from ever being a question.
- `releaseNotes` — `changelog` (section extraction), `file`, or `inline`. Paths
  are confined to the repository.
- Profile ids and package ids must match `.github/airo-build-profiles.json`; a
  test enforces that.

## APKPure specifics

APKPure has no publishing API, so `tools/publish/apkpure/` drives their
Developer Console with Playwright. Three hard rules:

1. **No password handling.** A human signs in once with
   `python3 -m tools.publish login apkpure`, which opens a headed browser and
   saves the resulting cookies to `~/.config/airo/apkpure-session.json`
   (override with `APKPURE_STORAGE_STATE`). Credentials never pass through this
   process, and no password belongs in a workflow secret.
2. **No CAPTCHA or 2FA solving.** A challenge stops the run with a screenshot
   and asks a human to take over.
3. **Selectors are data, not code.** Every step has a list of candidates, and
   `APKPURE_SELECTORS_FILE` can point at a JSON override — so a console redesign
   is unblocked by a config file, not by a code review.

### Cloudflare, and what this tool will not do

APKPure sits behind Cloudflare, which challenges Playwright's bundled Chromium.
This code will not evade that: no stealth plugins, no fingerprint or user-agent
spoofing, no automated challenge solving. What it does instead is let a human
drive a real browser through the check, and work inside the session that human
established. Pick a mode with `--browser`, the `browser` target option, or
`APKPURE_BROWSER`:

| Mode | What it does | When |
| --- | --- | --- |
| `bundled` (default) | Playwright Chromium replaying a saved storage state | Fast, headless-capable, most likely to be challenged |
| `chrome` | Real Google Chrome with a persistent profile that survives runs | Cloudflare challenges the bundled browser |
| `cdp` | Attaches to a Chrome you started and signed in yourself | Strongest option: nothing about the session is synthesised |

`chrome` and `cdp` need no storage state — the session lives in the browser
profile — and both run headed, because a human may need to clear a check.

Sign in to a persistent Chrome profile:

```bash
python3 -m tools.publish login apkpure --browser chrome
```

Or attach to your own browser. Start Chrome with remote debugging, sign in to
APKPure in that window, then run with `--browser cdp`:

```bash
'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --remote-debugging-port=9222 --user-data-dir="$HOME/.config/airo/apkpure-chrome-profile"
```

In `cdp` mode the tool attaches to a tab and detaches when done; it never closes
the browser you own.

If Cloudflare still blocks a real, human-signed-in Chrome, treat that as APKPure
declining automated uploads and publish that release by hand — `ManualPublisher`
exists for exactly this outcome.

### Selectors are UNVERIFIED

The candidates in `apkpure/selectors.py` are written against the documented
console flow but have **not** been recorded against the live DOM. Before the
first real run:

```bash
python3 -m tools.publish doctor apkpure --package-id io.airo.app.tv
```

It reports which selector keys matched nothing, dumps the page HTML and
screenshots into the evidence directory, and exits 2 if anything is unmapped.
Map the gaps, write the overrides, then flip `enabled: true` in the config.

### Where it should run

Cloud runners trigger CAPTCHA and device checks far more often than a machine
with a stable IP and a persistent profile. Run the APKPure leg on the self-hosted
Mac mini runner, and keep only the session state on disk — never a password.

## Evidence

Every attempt writes `build/publish-evidence/<target>/<profile>/<version>/`:

- `publish.log` — the full, credential-redacted command trail
- `*-plan.json` / `*-result.json` — what was intended and what happened
- `NN-*.png` / `NN-*.html` — browser stage snapshots (APKPure)
- `MANUAL_CHECKLIST.md` — for stores with no automation yet

## Adding a store

1. Subclass `Publisher` in `tools/publish/publishers/`, set `name`,
   `description`, and any `required_env` / `required_binaries`.
2. Implement `publish(ctx)`. Use `ctx.artifacts`, `ctx.release_notes`,
   `ctx.evidence`, and `self.run(...)` for subprocesses.
3. Gate anything irreversible behind `ctx.options.may_submit`.
4. Register it in `publishers/__init__.py` and add a config block.

Stores that cannot be automated yet subclass `ManualPublisher` instead: they
emit the human checklist and report `BLOCKED`, so a release run can never claim
a store was published when it was not.

## Tests

```bash
scripts/test-publish-framework.sh
```
