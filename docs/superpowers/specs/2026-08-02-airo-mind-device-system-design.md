# Airo Mind Device System — Milestone 22 design

Date: 2026-08-02
Status: P0 implemented; P1–P4 pending
Source design: Claude Design project `16cfaf17-5f73-426a-bede-40ba67659ed9`,
file `Airo Mind Device System.dc.html` (14 surfaces, 5 device classes, 0 servers)
Related: milestone 19 (runtime), milestone 20 (capability platform), epic #1192

## Why this milestone exists

Airo Mind has an architecture (frozen at v1, `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md`)
and a shipping surface of one meeting recorder. Milestone 19 holds 59 open issues of
runtime work and has not shipped a vault, an operation log, or a projection. The design
handoff supplies the other half: what the runtime looks like when a person uses it, on
every private device they own.

M22 builds those surfaces now, against a frozen port that M19 fills in behind. The
surfaces do not wait for the runtime, and the runtime does not get to invent an API
that no screen can consume.

## Scope

**In:** 14 surfaces across five device classes — phone, tablet, foldable, macOS,
Windows — plus Linux, which reuses the Windows layout.

**Out, by rule:** web and TV. See rule R05 below.

**Out, by decision:** the AI capability drafter (#1250) and the community capability
marketplace (#1247, #1251). Surface 06 renders both regions in their designed position
and disabled state; M20 fills them in without a redesign.

## Surface inventory

| # | Surface | Class | Backing ports |
|---|---|---|---|
| 01 | Mind Home | Phone | Vault, OperationLog, Context, Capability, Mesh |
| 02 | Local Agent Chat | Phone | Model, OperationLog, Context |
| 03 | Audio Scribe | Phone | Model, OperationLog, Context |
| 04 | Memory · Projections | Phone | Projection, Context, Vault |
| 05 | Devices & P2P Sync | Phone | Mesh, Vault |
| 06 | Capability Packs | Phone | Capability |
| 07 | Quick Capture | Phone | OperationLog, Context, Model |
| 08 | Portability · `.airobackup` | Phone | Portability, Context, Vault |
| 09 | Context Workspace | Tablet | Projection, Context, OperationLog |
| 10 | Prompt Lab + Model Bench | Foldable | Model, Context |
| 11 | Everything Browser | macOS | Projection, Context, OperationLog |
| 12 | Menu Bar Capture | macOS | OperationLog, Context, Model |
| 13 | Runtime Console | Windows, Linux | OperationLog, Model, Mesh, Vault |
| 14 | Tray Flyout | Windows, Linux | OperationLog, Mesh, Model |

## The five rules

Four come from the design. R05 comes from the product decision that Mind is for
private devices. All five are enforced by tests, not by review.

| Rule | Statement | Enforcement |
|---|---|---|
| R01 Presence | A teal status pip is on every screen. Teal means the work happened on this device. | Golden test per surface asserts the pip widget is present and reflects locality. |
| R02 Context | Every artefact wears its hypergraph tags. Tags are tappable everywhere, never decorative. | Widget test: every context chip has a tap target ≥ 48 px and resolves to a route. |
| R03 Projections | Graph, Timeline and Search are one switcher, never three destinations. | Lint: the three views may only be rendered through a single `ProjectionSwitcher`; no route may target one directly. |
| R04 Numbers | Ops counts, tok/s, peer counts stay visible. | Golden: the ops / peers / vault strip renders above the fold on every surface that has one. |
| R05 Private devices | Mind renders only on a device one person owns. | Build test: `flutter build web` and the TV flavor must not link `feature_mind`. |

R05 is a security property, not a scope cut. A personal vault must not render on a
shared screen. Enforcing it at link time rather than at runtime means a shared build
cannot be made to show a vault by flipping a flag.

## Architecture

### The port

`packages/feature_mind` becomes the Mind module. It exposes a Dart port,
`MindRuntime`, shaped to the frozen surfaces of the architecture — seven primitives,
contracts C1–C7, the six-function API. The port is split into eight sub-ports so that
no consumer takes a dependency wider than it uses and no file grows past what a
reviewer can hold.

| Sub-port | Responsibility |
|---|---|
| `VaultPort` | Seal state, root identity, device keys and certificates, revocation ledger and epoch |
| `OperationLogPort` | Append, count, range read, per-op signature verification, replay from a given op |
| `ContextPort` | Hypergraph: create, link, unlink, survival computation, per-context item counts |
| `ProjectionPort` | Knowledge graph, timeline, full-text search; rebuild and rebuild duration |
| `MeshPort` | mDNS peer discovery, pairing code, authorise / deny / revoke, ops-behind per peer |
| `CapabilityPort` | Installed capability list, manifest read, activate, remove |
| `ModelPort` | Installed models, load, download with progress, benchmark, thermal state |
| `PortabilityPort` | Recovery Package size breakdown, context selection, seal, destination |

Two implementations:

- `FixtureMindRuntime` — deterministic, seeded with the design's own numbers: 12,481
  ops, four contexts (#KneeSurgery2026 38, #DowntownApartment 17, #Q3TaxFiling 52,
  #AiroArchitecture 9), three LAN peers, one revoked device, Gemma 3n E4B at 24 tok/s
  and 1.9 GB, a 3.1-second projection rebuild.
- `RustMindRuntime` — delegates to `rust/airo_mind_runtime` over FRB. Ships partial:
  each port method reports `MindPortUnavailable` — naming the port and the M19 issue
  that fills it in — until that issue lands, and every surface already renders that
  state. Streaming methods fail on the stream rather than at call time, so a surface
  subscribes and renders an error rather than crashing before the subscription forms.

Surfaces bind to ports only. No screen imports the generated bridge. This is the
existing rule in `packages/feature_mind/lib/feature_mind.dart` — "a consumer that
reaches into `src/` has coupled itself to a code generator's output" — extended to the
whole module.

The port ships as a reviewed contract issue carrying a Contract Impact table, per
`docs/agents/AGENT_POLICY.md`. M19 implements against the port. The port does not
change to accommodate an implementation detail; if the runtime cannot satisfy a port
method, that is an architecture finding, recorded as an ADR, not a silent port edit.

### Layer split

Per the framework/application boundary in `CLAUDE.md`:

**Framework** (`packages/`): the eight ports, `FixtureMindRuntime`, the FRB binding,
`MindPalette`, and five shared widgets that carry the rules —

- `MindPresencePip` (R01)
- `MindContextChip` (R02)
- `MindProjectionSwitcher` (R03)
- `MindNumberStrip` (R04)
- `MindOpRow` — the op-provenance row: op number, signature state, originating device

`MindPalette` holds the handoff's colours. It is **not** `AppColors.cyber*` in
`core_ui`: that is the Living Console palette (#5CE1E6 on #F4F1EA) and this is the
Mind device system's (#7FE8DE on #FFE6CB). Two visual languages, not one with drift.
The three Airo faces — `AiroRulesExpanded`, `AiroMondwest`, `AiroCollapse` — did
already land in `app/pubspec.yaml`; the palette did not.

**Application**: the 14 screens, their copy, and their layout classes.

### Responsive strategy

One widget set, five layout classes, resolved through the breakpoints in
`docs/ui/RESPONSIVE_STANDARDS.md`. Two additions that document does not yet cover:

- **Foldable**: read the display feature hinge. The gutter falls between panes, never
  through a control. Unfolded 1080 × 880 is a two-pane layout, not a stretched phone.
- **Desktop**: macOS takes its chrome from the platform — menu bar, traffic lights,
  ⌘K — while the interior keeps the flat grid-line language of the phone. Windows and
  Linux take the dense operator layout: sortable log table, telemetry pinned right.

### Distribution

- `app/lib/main_mind.dart` with `pubspec_mind.yaml` — Mind is the whole app.
- Main Airo — Mind registers through `core_product_shell` as an `AppModule` (#1233),
  gaining a nav destination. Same widgets, same ports, no forked UI.
- Web and TV flavors — a no-op swap package, `packages/stubs/feature_mind_stub`,
  selected through `pubspec_overrides.yaml`. Same mechanism as
  `packages/airo_pro_bootstrap` and the rest of `packages/stubs`. The Mind module is
  absent from the binary, not disabled in it. It is the first stub to shadow a *local*
  package name, so melos ignores its path — it is reached by an override, never by
  name from the workspace.

### Data flow

Capture → sign with device key → append op → projections invalidate → rebuild →
surfaces re-render from the projection. Never from the op directly: projections are
disposable, and a surface that reads the log directly cannot be rebuilt.

`FixtureMindRuntime` simulates the same pipeline, including a 3.1-second rebuild, so
that timing copy on screen ("REBUILT 3.1S AGO") is honest under fixtures as well as
under the real runtime.

### Error handling

Every surface has three defined non-happy states, and each shows a number rather than
a spinner:

- **Runtime unavailable** — `MindUnavailable` already exists in `MindService`; the
  port reuses it. Surface states which sub-port is missing.
- **Projection rebuilding** — shows ops processed of ops total.
- **Peer offline / behind** — shows ops behind, not a generic "syncing".

## Testing

- Golden test per surface per applicable device class.
- One widget test per rule, per surface: R01–R04.
- One build test for R05: web and TV flavors must not link `feature_mind`.
- `FixtureMindRuntime` is the test double everywhere. No screen test constructs
  ad-hoc fake data.
- The rule harness lives at `packages/feature_mind/test/support/mind_rule_harness.dart`,
  not in `lib/`. Every Mind surface lives in this package so every surface test reaches
  it by relative import, and shipping it from `lib/` would drag `flutter_test` into a
  production package's dependency graph. Promote it to its own package the day
  something outside this package needs it.
- One integration test per entrypoint: standalone Mind boots to Mind Home; main Airo
  boots and reaches Mind through the shell.
- Mutation property, per the governance stack already in force on Mind: each of R01–R05
  has a test whose only failing cause is removing that rule's enforcement.

## Phases

**P0 — Contract.** `MindRuntime` and its eight sub-ports. `FixtureMindRuntime`. The
five shared widgets. The conformance harness for R01–R04, plus repo gates for R03 and
R05. Free the Mind name (#1203) — two things called "mind" in one app churn every
subsequent phase.

That last item was larger than #1203 describes. `app/lib/features/mind` was not the
wellbeing hub: it was the AI hub — three wellbeing cards and eight AI ones on one
screen called Mind, holding `/mind`, `AppNavigationTab.mind` and the tab label, across
15 files and ten sub-routes. Renaming it wholesale to "wellbeing" would have put Prompt
Lab and Model Benchmark under a tab called Wellbeing, so it was **split**: `/assistant`
keeps the AI lab and the nav tab, `/wellbeing` is a pushed destination for reflection
and breathing. Notification deep links written before the split are migrated in
`NotificationNavigationService` rather than by a router redirect, so the old path stays
out of the route table and `/mind` is genuinely free for P4.

**P1 — Phone.** Surfaces 01–08.

**P2 — Tablet and foldable.** Surfaces 09 and 10, plus the crease rule and the
inspector.

**P3 — Desktop.** Surfaces 11–14, plus Linux.

**P4 — Integration.** AppModule registration, web and TV exclusion, both entrypoints
ship.

## Feature requests

Gaps in the design that no existing issue covers. Each becomes an issue in M22.

1. **Quick Capture as an OS surface** — macOS menu bar extra, Windows tray flyout,
   Linux tray. The panel commits a note without opening the app.
2. **Global hotkey registration and per-OS permission flow** — ⌘⇧Space,
   Win+Shift+Space, and the Linux equivalent, including the permission prompts each
   platform requires.
3. **Model Bench** — tok/s, first token, RAM, battery per hour, NPU utilisation,
   thermal state, and automatic re-benchmark on thermal state change. Benchmarks run
   against the user's own hardware, not a spec sheet.
4. **Model download manager** — progress, pause on mobile data, storage budget
   (6.8 / 12 GB), resident versus loaded distinction.
5. **Agent Chat grounded citations** — tool-call disclosure card stating how much data
   moved, `GROUNDED IN` block citing the exact op number, and the wellness-only safety
   banner. A claim must always be traceable to an op.
6. **Audio Scribe two-party consent gate** — a blocking banner, not a settings toggle;
   all parties notified; jurisdiction-aware. Store-safety class.
7. **Windows Runtime Console** — the append-only log as a sortable table, every row
   signed and attributed to a device, right-click to replay from that point.
8. **macOS Everything Browser** — ⌘K palette, three-column browser, native menu bar.
9. **Foldable crease-aware layout rule** — added to
   `docs/ui/RESPONSIVE_STANDARDS.md`.
10. **Entity extraction and Inspector** — extracted entities, linked contexts,
    projections touched, replay-from-log action.
11. **`.airobackup` destination picker and size breakdown** — LAN peer, this device,
    USB drive; content-class size split. Extends #1211.
12. **Private-device gating** — the `packages/stubs/feature_mind_stub` swap package and the R05
    build test.

## Council review

| Reviewer | Owns |
|---|---|
| chief-architect | The port contract and its Contract Impact table |
| chief-ux-officer | R01–R04, responsive strategy, the crease rule |
| platform-architect | Menu bar, tray, global hotkeys, per-OS permission flow |
| chief-security-officer | R05, the consent gate, revocation and shredding copy |
| chief-performance-officer | Model bench claims, projection rebuild timings |

## Open dependencies

- M19 must implement against the P0 port. If it lands first for a given sub-port,
  `RustMindRuntime` swaps in for that port with no surface change.
- #1233 (register Mind through `core_product_shell`) is a P4 prerequisite and already
  exists in M19; it should be retargeted to M22 P4.
- #1203 (wellbeing rename) is pulled into P0.
- #1211 (Recovery Package export) is extended by feature request 11, not duplicated.
