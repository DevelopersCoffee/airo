# Airo Mind heavy push — Runtime v1 + On-Device LLM, combined prompt

Paste as-is to drive both milestones in parallel.

---

Repo: DevelopersCoffee/airo. Two milestones, run concurrently, separate worktrees — they touch disjoint subsystems (`rust/airo_mind*` runtime core vs `rust/airo_mind_llama`/`airo_mind_whisper`) but both feed the same Mind runtime, so integration issues (#1657) are the seam to watch.

## Track A — Milestone 19: Runtime v1 (infra bet, blocks everything downstream)

Exit criterion is not a task list, it's #1311 — the ten conditions (C1–C7 contracts in `docs/superpowers/specs/2026-07-28-airo-mind-runtime-contracts.md`). Do not treat any condition as done without an automated conformance test (condition 9) — four prior council reviews caught properties "recorded as applied and absent from the code."

**Step 0 — entry point, nothing else in Track A starts before this:**
- #1302 Runtime Supervisor (lifecycle, cancellation, resource limits) — blocks conditions 1 and 2
- #1338 Runtime Skeleton epic — the vertical slice: `Operation → Persist → Replay → Projection → UI` through a minimal Notes capability only. Scope is deliberately small — AI, sync, workflows, and all capabilities beyond Notes are explicitly OUT. Do not let scope creep in.

**Step 1 — parallel once skeleton boots:**
- #1194 Operation log (condition 4)
- #1195 Projection engine — must support delete+rebuild with zero data loss (condition 5)
- #1305 Vault redesign (condition 6 — Recovery Package restore reproduces identical state)
- #1293 Migrate feature storage onto runtime via shared adapter — closes 4 known I4 violations: `DriftMeetingRepository`, `features/coins/`, `features/money/`, settings AI-storage dashboard, plus #1297 `relational_store`

**Step 2 — depends on Step 1 landing:**
- #1200 Sync (condition 7 — two devices converge by exchanging operations only)
- #1217 Purge/destroy mechanism (condition 8 — currently convention, not enforced)
- #1287, #1294 Conformance suite + benchmark gates in CI (conditions 9, 10 — build these alongside Step 1, not after; per the epic, 9/10 without 1–8 is claimed, not met)

**Step 3 — architecture/type-system work, can run alongside Steps 1–2:**
- #1223 Type system (primitives, archetypes, ontology)
- #1225 Four DSLs (Graph, Workflow, View, Automation)
- #1226 Schema fingerprint + compatibility classes
- #1227 Context templates
- #1229 Context hypergraph
- #1230/#1231/#1232 Notes capability, capability removal safety, Mind shell UI

Rule: any capability requesting an exception from the runtime contracts is a permanent maintenance cost per the epic — reject or escalate, don't grant silently.

## Track B — Milestone 26: On-Device LLM + Meeting Intelligence (Pro, feature bet)

Full execution order and delegation matrix already recorded on #1627 — follow it as written, don't re-derive:

| Wave | Issues | Gate |
|---|---|---|
| 0 Audit | #1655, #1628, #1629, #1630, #1657 contract | findings recorded on each issue |
| 1 Foundation | #1655 build wiring, #1628 LlmBackend trait, #1629 ASR, #1630 model mgr | macOS CLI: GGUF gen + timestamped transcript from real .m4a |
| 2 Pipeline core | #1632 → #1633; #1631 alongside | POC-1: golden MoM reproduced from existing transcript |
| 3 Trust layer | #1634 → #1635; #1636 harness | POC-2/3: full offline audio→MoM, all facts evidence-grounded |
| 4 Integration | #1657, #1656, #1637 | POC-4: model picked by bench, IR queryable in Mind surfaces |
| 5 Product surface | #1658, #1638, #1640 | POC-5/6: macOS E2E, then Pixel 9 rig |

Ground truth: Phase 1 already partially exists (`rust/airo_mind_whisper`, `rust/airo_mind_llama`, `MindSpeechBridge`/`MindGenerationBridge`, `ModelDownloadService`). #1628/#1629/#1630 are harden-and-extend, not greenfield. #1641 POC ladder is the standing gate tracker — check it after every wave.

Architectural rule, non-negotiable: LLM never summarizes transcript directly. Meeting IR (with per-fact evidence — segment IDs) is the product; MoM/action-items/search are projections of it.

Quality gates before calling any wave done: ASR term accuracy ≥90%, decision/action-item F1 ≥90%, numeric accuracy ≥95%, evidence accuracy ≥95%, unsupported-claim rate ≤2%.

Non-goals this milestone: speaker diarization, TTS, multi-engine STT, 7B+ models.

Pro boundary: all product code lands in private `airo-pro` overlay via `pubspec_overrides.yaml` seam. Public repo only widens `core_native` FFI surface + entitlement hooks. Never put meeting-intelligence product logic in the public tree.

## Cross-track seam

#1657 (Mind IR ↔ runtime integration) is the point where Track B's Meeting IR needs to land through Track A's operation log / projection engine, not a bespoke store. If Track A's Step 1 (#1194/#1195) isn't done when Track B reaches Wave 4, #1657 blocks — flag it early rather than letting Track B build a parallel persistence path (that's exactly the I4 violation pattern #1293 exists to undo).

## Delegation (per [[delegation-workflow]] memory)

Claude architects contracts/schemas/trait shapes; cheaper models implement plumbing and tests against them. Full matrix for Track B is on #1627. For Track A, Claude-only on: Supervisor lifecycle contract (#1302), operation log schema (#1194), the four DSL grammars (#1225), conformance test contracts (#1287). Delegable: adapter migration plumbing (#1293), capability CRUD once contracts exist (#1231/#1232).

## Rules for every PR in both tracks

- Base off `origin/main`
- Route review by nearest agent: rust-architect (Rust core), platform-architect (FFI), chief-architect (contracts), chief-security-officer (vault/crypto), chief-performance-officer (benchmarks/tier-gating), chief-qa-officer (conformance/eval), chief-ux-officer (#1658 UI)
- Narrowest CI job per CLAUDE.md GH-minutes policy
- No feature work rides in a Track A PR; no runtime-substrate work rides in a Track B PR — if a Track B issue needs a Track A primitive that doesn't exist yet, stop and flag rather than building a local workaround

Report progress per track after each issue lands. If Track A Step 0 isn't done, Track B can still work Waves 0–1 (they don't need the skeleton yet) — don't stall Track B on Track A.
