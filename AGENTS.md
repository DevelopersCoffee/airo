# Airo — agent context

Local-first Flutter super app: AI chat, personal finance, TV/IPTV, music, games,
and reading in one codebase. Melos workspace — `packages/` is framework, `app/`
is product. 62 packages carry a `module.yaml` declaring their council owner.

**This file is the single context source for every agent.** `CLAUDE.md`,
`GEMINI.md`, and `.augment/rules.md` are symlinks to it, so Claude Code, Codex,
Gemini, Antigravity, Augment, and anything else reading a conventions file all
get the same text. Never add a second, tool-specific rules file — put the
content here, or in a load-on-demand doc below.

## Gotchas

**Parsing never runs on the main isolate.** Any parse, JSON decode, M3U/EPG
transform, or serialization over ~50 KB goes through `runOffMain()` from
`packages/core_workers`, or `platform_worker_jobs` / `AiroWorkerExecutor` for a
reusable job boundary. Screen-local `compute()` or `Isolate.run` inside
presentation code is a lint violation: application modules consume platform
services rather than spawning their own workers. Synchronous helpers stay fine
for tests and small deterministic parsing. The Rust core (`packages/core_native`)
will replace many of these call sites, but the isolate boundary must survive as
the web fallback.

**Flavors are separate pubspecs, not build flags.** `app/pubspec.yaml` (phone),
`pubspec_tv.yaml`, `pubspec_coins.yaml`, `pubspec_patrol.yaml`,
`pubspec_ios_spm.yaml` — each pairs with its own entrypoint in `app/lib/`
(`main.dart`, `main_tv.dart`, `main_coins.dart`, `main_qualification.dart`). A
dependency added to one is invisible to the others.

**`packages/airo_pro_bootstrap` is a deliberate no-op.** The private `airo-pro`
overlay swaps a same-named package in through `pubspec_overrides.yaml`, the same
mechanism as `packages/stubs`. Never put pro logic in the public copy — only
widen the seam (`createEntitlements`, `registerProModules`) when the overlay
needs it.

**Web has no `dart:ffi`.** Drift/SQLite and other native paths need a
`*_stub.dart` no-op picked by conditional import —
`import 'x_stub.dart' if (dart.library.io) 'x_native.dart';`. Plugin-level gaps
use the swap packages under `packages/stubs/`. Run
`cd app && flutter build web --release` before landing anything that touches a
native path.

**Framework and application layers do not cross unilaterally.** Framework owns
contracts, runtime boundaries, storage schemas, security rules, and platform
abstractions. Application owns journeys, screens, copy, routine packs, and
templates. Cross-boundary work needs an explicit contract recorded in the issue
before code.

**Release lines.** Active work branches from `origin/main`. `origin/v1_bkp` is
the frozen pre-swap monolith, kept for reference and recovery — base on it only
when an issue names it.

**GitHub Actions minutes are a costed shared resource.** Prove the touched
contract with the narrowest local analyzer/test/format run; full matrices and
release workflows are opt-in. `[skip ci]` is for non-executable changes only —
a `commit-msg` hook rejects the rest (`make install-hooks`).

## Load when relevant

| Doing | Read |
|---|---|
| Any feature, fix, or architecture change | [docs/agents/AGENT_POLICY.md](docs/agents/AGENT_POLICY.md) — lifecycle gates, Critical Agent, cross-agent contracts |
| Deciding who must review | [docs/agents/COUNCIL.md](docs/agents/COUNCIL.md) — module ownership, decision matrix, `module.yaml` schema |
| Branching, worktrees, CI spend, closing issues | [docs/agents/WORKFLOW.md](docs/agents/WORKFLOW.md) |
| Public site or release copy | `.agents/skills/airo-release-branding/SKILL.md` |
| Running Airo TV locally | `.claude/skills/run-airo-tv/SKILL.md` |
| TV / leanback UI | `.claude/skills/android-tv-design/SKILL.md` |
| Any screen that spans phone, tablet, TV, or web | [docs/ui/RESPONSIVE_STANDARDS.md](docs/ui/RESPONSIVE_STANDARDS.md) |
| Editing this file or the docs it points at | [docs/agents/CONTEXT_ENGINEERING.md](docs/agents/CONTEXT_ENGINEERING.md) |

## Cursor Cloud specific instructions

The Cloud Agent VM boots with Flutter **3.44.4** (`/opt/flutter`, symlinked to
`/usr/local/bin` as `flutter`/`dart`/`melos`, so they're on `PATH` by default —
no profile sourcing needed). The startup update script runs `melos bootstrap`
then `bash scripts/run-ci-codegen.sh`; everything below is context that isn't
obvious from that.

- **This is a Dart pub workspace, not classic Melos linking.** `melos bootstrap`
  resolves the whole tree with a single root `dart pub get`, so its
  `-> 0 packages bootstrapped` line is expected success, not an error. There are
  no committed `pubspec_overrides.yaml`.
- **`feature_mind` freezed output is gitignored and must be generated before the
  app analyzes/compiles.** `scripts/run-ci-codegen.sh` does this (and
  deliberately skips app-level `build_runner` — riverpod_generator 4.0.8 cannot
  compile on the analyzer 12 pin, and the committed Drift output is enough).
- `app/lib/firebase_options.dart` is a committed placeholder; when unconfigured,
  Firebase is gracefully skipped/deferred, so login/sync just aren't exercised.
- **No emulator/physical device is available — run on Flutter web.** Serve the
  app with `cd app && flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 -t lib/main.dart`
  (swap the `-t` entrypoint for other flavors: `main_tv.dart`, `main_coins.dart`,
  `main_mind.dart`, `main_qualification.dart`). The `web-server` device compiles
  Dart→JS lazily in the browser, so the first load shows a blank/white screen for
  ~30s–3min — this is normal, keep waiting. Log in with the "Fill Demo
  Credentials" button (demo / demo123).
- **Known web-only limits (not bugs):** Drift/SQLite persistence in the finance
  ("Coins") feature is unavailable on web (native `dart:ffi` path), and IPTV
  remote-playlist fetches are blocked by the VM egress policy. The Games
  ("Arena") feature is a fully self-contained way to exercise core functionality.
- Lint/test: `flutter analyze` / `flutter test` per package, or `melos run
  analyze` / `melos run test` across the workspace (see `melos` scripts in the
  root `pubspec.yaml`). Web build sanity check for native-path changes:
  `cd app && flutter build web --release`.
