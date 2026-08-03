# Airo Mind P1 — the eight phone surfaces

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the eight phone surfaces of the Airo Mind device system at 390 × 844, bound to the `MindRuntime` port that P0 froze, each satisfying rules R01–R04 and rendering its three non-happy states.

**Architecture:** Every surface is a `ConsumerWidget`-free `StatefulWidget` taking a `MindRuntime` and nothing else. A shared `MindSurfaceScaffold` supplies the status bar, title row and number strip so R01 and R04 hold structurally rather than per screen. Surfaces read through sub-ports only; `FixtureMindRuntime` is the test double and the golden fixture.

**Tech Stack:** Flutter, `flutter_test`, `alchemist ^0.14.0` (already a workspace dev-dependency in `app` and `core_ui`).

**Issue:** [#1450](https://github.com/DevelopersCoffee/airo/issues/1450) · **Epic:** [#1448](https://github.com/DevelopersCoffee/airo/issues/1448)
**Design:** `docs/superpowers/specs/2026-08-02-airo-mind-device-system-design.md`, surfaces 01–08
**Source:** `Airo Mind Device System.dc.html`, lines 83–747

## Global Constraints

- Every surface test calls `expectSatisfiesMindRules(tester)` from
  `test/support/mind_rule_harness.dart`. A surface without it is not done.
- **No new third-party dependencies.** `alchemist` moves into
  `feature_mind`'s `dev_dependencies` — already used by `app` and `core_ui`, so
  it needs no scorecard.
- Surfaces bind to sub-ports. Nothing in `lib/src/surfaces/` may import
  `src/api/` or `frb_generated`; `test/module_contract_test.dart` enforces this
  on `lib/src/runtime` and `lib/src/widgets` and must be extended to
  `lib/src/surfaces`.
- Colours come from `MindPalette`. No raw `Color(0x…)` in a surface.
- **Three non-happy states per surface**, each showing a number rather than a
  spinner: runtime-unavailable (naming the missing sub-port),
  projection-rebuilding (ops processed of total), peer-offline (ops behind).
- No `DateTime.now()` in a surface. Time comes from the runtime, so goldens do
  not move with the clock.
- Device verification is **deferred to a device pass**, not skipped. Host
  verification is `flutter test` plus goldens at 390 × 844.
- Verification, from `packages/feature_mind`:
  - `flutter test`
  - `flutter test --update-goldens` to regenerate
  - `flutter analyze --fatal-infos`
  - `dart format -o none --set-exit-if-changed lib test`
- Repo gates, from the root: `scripts/check-mind-projection-routes.sh` and
  `scripts/check-mind-private-devices.sh`.

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `lib/src/surfaces/mind_surface_scaffold.dart` | Status bar, title row, number strip, non-happy states — carries R01 and R04 for every surface |
| `lib/src/surfaces/mind_home_surface.dart` | 01 |
| `lib/src/surfaces/agent_chat_surface.dart` | 02 |
| `lib/src/surfaces/audio_scribe_surface.dart` | 03 |
| `lib/src/surfaces/memory_surface.dart` | 04 |
| `lib/src/surfaces/devices_surface.dart` | 05 |
| `lib/src/surfaces/capabilities_surface.dart` | 06 |
| `lib/src/surfaces/quick_capture_sheet.dart` | 07 |
| `lib/src/surfaces/portability_surface.dart` | 08 |
| `test/support/surface_harness.dart` | `pumpSurface()` at 390 × 844 + `goldenSurface()` |
| `test/surfaces/*_test.dart` | One per surface |
| `test/surfaces/goldens/*.png` | One per surface |

**Modified**

| Path | Change |
|---|---|
| `pubspec.yaml` | `alchemist` dev-dependency |
| `lib/feature_mind.dart` | Export the surfaces |
| `test/module_contract_test.dart` | Extend the bridge check to `lib/src/surfaces` |

---

### Task 1: Surface scaffold, golden harness, and the bridge-check extension

The scaffold is what makes R01 and R04 structural. A surface that uses it
cannot forget its pip or its numbers, which is a stronger guarantee than a test
that catches the omission afterwards.

**Files:**
- Create: `lib/src/surfaces/mind_surface_scaffold.dart`
- Create: `test/support/surface_harness.dart`
- Modify: `pubspec.yaml`, `lib/feature_mind.dart`, `test/module_contract_test.dart`
- Test: `test/surfaces/surface_scaffold_test.dart`

**Interfaces:**
- Consumes: `MindPresencePip`, `MindNumberStrip`, `MindPortUnavailable`, all ports.
- Produces:
  - `MindSurfaceScaffold({required String title, required MindSurfaceStatus status, Widget? trailing, required Widget child})`
  - `MindSurfaceStatus.live({required int opCount, required int peerCount, required bool vaultSealed, bool isLocal})`,
    `.unavailable(String port, String reason)`, `.rebuilding({required int opsProcessed, required int opsTotal})`
  - `pumpSurface(WidgetTester, Widget)` — pumps at 390 × 844
  - `goldenSurface(String name, Widget)` — Alchemist golden at 390 × 844

- [ ] **Step 1: Write the failing test** — assert the scaffold renders pip + strip; that `unavailable` names the port and shows no strip; that `rebuilding` shows `6,240 of 12,481`, not a bare spinner.
- [ ] **Step 2: Run it, confirm it fails** on the undefined symbols.
- [ ] **Step 3: Add `alchemist: ^0.14.0` to dev_dependencies**, `flutter pub get`.
- [ ] **Step 4: Write `MindSurfaceScaffold`** — a `Column` of status row (time + `MindPresencePip`), title row, `MindNumberStrip` when `status.isLive`, then `child`. For `unavailable`, render the port name, the reason, and a retry affordance; no strip. For `rebuilding`, render `opsProcessed of opsTotal`.
- [ ] **Step 5: Write `pumpSurface` and `goldenSurface`** in `test/support/surface_harness.dart`.
- [ ] **Step 6: Extend the bridge check** in `module_contract_test.dart` to include `lib/src/surfaces`.
- [ ] **Step 7: Run tests, analyze, format, commit.**

---

### Tasks 2–9: One per surface

Each follows the identical cycle, so it is written once rather than eight
times. For surface *N*:

- [ ] **Step 1:** Write `test/surfaces/<name>_test.dart` — content assertions from the design, `expectSatisfiesMindRules(tester)`, and the three non-happy states.
- [ ] **Step 2:** Run it; confirm it fails on the undefined surface.
- [ ] **Step 3:** Write `lib/src/surfaces/<name>.dart` against its sub-ports.
- [ ] **Step 4:** Run the test to green.
- [ ] **Step 5:** Add the golden, generate with `--update-goldens`, and eyeball the PNG against the design before committing it. **A golden accepted without looking at it is a screenshot, not a test.**
- [ ] **Step 6:** Export from `feature_mind.dart`; analyze, format, commit.

| Task | Surface | Ports | The thing that must be true |
|---|---|---|---|
| 2 | 01 Mind Home | Vault, OperationLog, Context, Capability, Mesh | A runtime dashboard, not a feed: ops, peers and vault above the fold; three capture actions; four context chips; four capability cards; recent-log rows |
| 3 | 04 Memory · Projections | Projection, Context, Vault | Graph/Timeline/Search on one `MindProjectionSwitcher`. Deleting a context states crypto-shredding in plain words at the moment of deletion |
| 4 | 05 Devices & P2P | Mesh, Vault | Revoked devices stay listed as evidence. Pending pairing shows the six-digit code. Copy: revocation is O(contexts), never O(content) |
| 5 | 06 Capability Packs | Capability | Installed list + sandbox limits printed on the row. Drafter and community regions render **in position, disabled** — M20 fills them without a redesign |
| 6 | 08 Portability | Portability, Context, Vault | Size breakdown by content class; unchecking a context moves the number; passphrase warning **before** sealing; three destinations, none a server |
| 7 | 02 Local Agent Chat | Model, OperationLog, Context | Tool calls shown with bytes-moved; answers cite `op N`; safety banner driven by the context's `CapabilitySafetyClass`, not hardcoded |
| 8 | 03 Audio Scribe | Model, OperationLog, Context | Consent is a **blocking banner**, not a toggle — no path reaches the encoder without it. Stopping files the transcript into a context |
| 9 | 07 Quick Capture | OperationLog, Context, Model | Bottom sheet, hold-to-talk. Transcription lands before release; the context guess is overridable; capture never blocks on classification |

Surfaces 02, 03 and 07 depend on `ModelPort` behaviour the fixture supplies but
the real runtime does not yet; they render the unavailable state under
`RustMindRuntime` and that is correct.

Task 8 (Audio Scribe) implements the **consent gate UI only**. The enforcement
that no code path reaches the encoder without it is
[#1459](https://github.com/DevelopersCoffee/airo/issues/1459) and is
store-safety class — this task must not be read as closing it.

---

### Task 10: Sweep

- [ ] Every surface exported and reachable from `MindHomeSurface`.
- [ ] `expectSatisfiesMindRules` called in all eight tests — assert by grepping the test directory, so adding a ninth surface without it fails.
- [ ] All three non-happy states covered per surface.
- [ ] Both repo gates pass; `feature_mind` and `app` suites green; analyzer and format clean.
- [ ] Golden count equals surface count.

## Deferred, deliberately

- **Device verification** — a real 390 × 844 pass on the Pixel 9. Host goldens
  prove layout, not feel.
- **Council review** — Chief UX Officer owns R01–R04 and the copy; no P0 PR
  received a review and P1 should not repeat that.
- **Consent enforcement** (#1459), **grounded-citation machinery** (#1458),
  **model bench** (#1456) — P1 renders these; the feature requests make them
  real.
