# Airo Multi-Agent Ownership Policy

> Version: 1.0.0
> Effective: 2026-06-23
> Applies to: every feature, bug fix, architecture change, and automation flow

## Purpose

Airo is now planned as a local-first LLM OS: Brain, Agent Skills, Memory,
Scheduled Automations, Routine Packs, and domain apps all share framework
contracts. To keep the framework strong and the application layer deterministic,
each change must start with explicit agent ownership, contracts, and automation
flows before implementation.

This policy is mandatory. Agents must not begin feature code until the lifecycle
gates below are satisfied in the GitHub issue or linked planning artifact.

## Core Rule

Framework code is decided by framework-owning agents. Application behavior is
decided by application/domain-owning agents. Cross-boundary work requires an
explicit contract before code changes.

## Spec-Driven Rule

AI can accelerate implementation, but it does not remove the need for explicit
requirements, architecture, verification, and human review. Every non-trivial
change must start with a Feature Packet that captures the problem, owner,
contract, deterministic use cases, automation flows, evaluation plan,
security/privacy posture, and rollback plan.

The Kaggle adoption plan records how Airo applies these practices:
`docs/agents/KAGGLE_VIBE_CODING_ADOPTION.md`.

## Agent Roles

### Critical Agent

The Critical Agent runs before implementation. Its job is to make ambiguity
expensive and clarity cheap.

Responsibilities:
- Ask what problem is being solved and for whom.
- Identify owner agents and impacted modules.
- Decide whether the change is framework, application, or mixed.
- Require deterministic use cases and automation flows.
- Challenge hidden assumptions, missing failure paths, and unclear acceptance
  criteria.
- Block implementation if ownership, contract, or tests are unclear.

Required questions:
- What user journey or system behavior are we changing?
- What code owns this behavior today?
- Is this a reusable framework capability or an application-level workflow?
- Which agents must approve the contract?
- What data is created, read, updated, deleted, exported, or retained?
- What must happen offline, without a model, without permission, or after a
  runtime failure?
- What automation flow will prove this is correct?
- What does the finished UX or API look like?

### Framework Agent

Owns reusable foundations:
- AI runtime interfaces and model routing
- Agent Skill execution contracts
- tool permission boundaries
- Memory Vault schemas and retrieval primitives
- scheduled automation primitives
- database migrations and storage contracts
- platform channels and native adapters
- security, privacy, and audit primitives

Framework Agent must keep APIs stable, documented, and testable. It should not
encode product-specific journeys unless those are declared extension points.

### Application Agent

Owns end-user workflows:
- Brain screens and chat journeys
- Routine Pack UX and templates
- Airo OS Home composition
- habit, cleaning, finance, meeting, media, and other domain flows
- copy, empty states, onboarding, and user-facing error handling
- product-specific orchestration of framework capabilities

Application Agent must not bypass framework contracts for convenience.

### Domain Agents

Full current roster with package ownership lives in
[COUNCIL.md](./COUNCIL.md) — that file is the source of truth, this list is
just an index:

- Airo TV domain (Flutter, Rust, Playback, Media Intelligence, TV Experience,
  Platform, Edge Architects; Chief Cloud Officer owns the auth/entitlements/
  session packages) — supersedes the former generic "Media Agent" / "Mobile
  UI Agent" entries for all Airo TV work.
- Brain / AI Agent — no packages yet; owns product-layer Brain/chat journeys
  once built. `core_ai`, `core_ai_delegation`, `core_delegation` stay with
  Framework Agent below (runtime/model-routing, not a product journey).
- Coins / Finance Agent — `feature_coin`, `platform_coin_vault`, and future
  `platform_coin_*` / coin plugin packages. `packages/airomoney` is retired;
  `app/lib/features/coins` is a legacy extraction source, not the home for new
  Airo Coin behavior.
- Meeting Intelligence Agent — dormant, no packages yet
- Agent Skills Agent, Memory Agent, Routine OS Agent — super-app-level,
  unchanged, no owned packages exist yet in this repo pass

Domain agents define domain invariants, workflows, and acceptance criteria.
They consume framework contracts instead of redefining infrastructure locally.

### Security and Privacy Agent

Owns:
- local-first routing rules
- secret handling
- permission prompts and scopes
- tool-call redaction
- data retention and deletion
- remote model/network opt-in boundaries
- community skill sandboxing and provenance

Security review is required for memory, tools, skills, file access, network,
notifications, finance, health, contacts, location, and background automation.

### QA Automation Agent

Owns deterministic verification:
- user journey automation flows
- fixtures, mocks, stubs, and clocks
- database and state assertions
- tool trace assertions
- failure-path tests
- accessibility and timeout checks

QA Automation Agent must write or approve the automation flow before feature
implementation starts.

### Release and DevEx Agent

Owns:
- CI gates and GitHub Actions cost controls
- build/release workflows
- local developer commands
- docs completeness checks
- regression matrices
- artifacts, signing, and release notes

## Ownership Map

Airo TV package ownership (Flutter, Rust, Playback, Media Intelligence, TV
Experience, Platform, Edge) plus the Chief Cloud Officer's ownership of
`core_cloud_orchestration`/`core_auth`/`core_entitlements`/`core_sessions`/
`core_device_merge`, and the full decision matrix, now live in
[COUNCIL.md](./COUNCIL.md) — do not duplicate that table here. Remaining
super-app-level areas not yet covered by COUNCIL.md:

| Area | Primary Owner | Secondary Review |
| --- | --- | --- |
| `packages/core_ai`, model routing, LiteRT/HF contracts | Framework Agent | Security, QA |
| Agent Skills runtime, MCP, Google AI Edge compatibility | Agent Skills Agent | Framework, Security |
| Memory Vault, entities, retrieval, retention | Memory Agent | Security, QA |
| Scheduled automations, notifications, tool execution traces | Framework Agent | Agent Skills, Security |
| Brain chat, Prompt Lab, Ask Image, Audio Scribe UI | Brain / AI Agent | Mobile UI, QA |
| Routine Packs, templates, habit coach, Airo OS Home | Routine OS Agent | Mobile UI, Memory |
| Coins and finance workflows | Coins / Finance Agent | Security, QA |
| Meeting recording, transcription, speaker identity | Meeting Intelligence Agent | Security, Memory |
| CI/CD, release, automation infrastructure | Release and DevEx Agent | QA |

## Lifecycle

```text
INTAKE
  -> CRITICAL_AGENT_CLARITY_GATE
  -> OWNERSHIP_ROUTING
  -> CONTRACT_DRAFT
  -> AUTOMATION_FLOW_DRAFT
  -> IMPLEMENTATION
  -> CROSS_AGENT_REVIEW
  -> QA_HARDENING
  -> RELEASE_READY
```

### 1. Intake

The issue must state:
- problem
- target user or system actor
- expected outcome
- impacted modules
- known constraints
- links to parent roadmap issues

Before any branch, worktree, or implementation starts, the task owner must
sync against the latest release-line base. No agent may start from an older
local branch tip, a stale worktree, or an unverified checkout.

Release-line bases:

- Active development and current modular/release-profile work starts from `origin/main`.
- The legacy pre-swap monolith line is preserved at `origin/v1_bkp` for reference or recovery only.
- If an issue explicitly targets an older v1 artifact or historical branch state, name that base branch in the issue instead of assuming it.

Required bootstrap sequence:
- `git fetch origin main v1_bkp`
- choose `origin/main` for active work, or `origin/v1_bkp` only when the issue explicitly requires the legacy line
- create the task branch or worktree from that chosen remote base
- verify the task branch/worktree base matches the fetched remote base

If new commits land on `main` or `v2` before implementation starts, the agent
must repeat this sync step and restack or recreate the worktree as needed.

### CI Cost Control

GitHub Actions minutes are a costed resource. During iterative issue work,
agents must avoid unnecessary remote builds and use focused local validation
first.
For current v2.0.0.0 development, agents should treat remote CI as opt-in
during issue iteration and integration-branch merges. Local validation plus
recorded evidence in the issue is enough to close issues unless the maintainer
explicitly requests CI or the change is a release verification step.

Required cost controls:
- Run the smallest useful local checks for the touched module before pushing:
  formatting, analyzer/lint, targeted tests, and `git diff --check` as
  applicable.
- Add `[skip ci]` to iterative issue commits and merge commits unless the user
  explicitly requests remote CI or the change is a release verification step.
- For v2 work, push issue branches and the `codex/next-v2.0.0.0` integration
  branch. Do not push directly to `v2` just to validate work in progress.
- Avoid empty commits, no-op pushes, repeated metadata-only pushes, and branch
  churn that can trigger workflows without changing reviewable behavior.
- Do not hold an otherwise complete issue open only to wait for remote CI when
  the acceptance criteria are met by focused local validation.
- Close GitHub issues as soon as the acceptance criteria are met and the issue
  records the required policy artifacts, deterministic use cases, and
  validation evidence.

If remote CI is intentionally required, explain why in the issue or PR before
pushing without `[skip ci]`.

### 2. Critical Agent Clarity Gate

Before coding, add a comment or issue section:

```markdown
## Critical Agent Gate

**Problem:** ...
**User / actor:** ...
**Framework or application layer:** ...
**Owning agent:** ...
**Reviewing agents:** ...
**Impacted modules/files:** ...
**Base branch/worktree:** <confirmed from latest origin/main or origin/v1_bkp or another explicitly named base: yes/no>
**Open questions:** ...
**Decision:** Ready / Blocked
```

If the decision is `Blocked`, implementation stops until questions are answered.

### 3. Ownership Routing

Declare one primary owner. Other agents may review but should not create
parallel implementations.

Rules:
- If a reusable API, schema, permission, runtime, or platform abstraction is
  changed, Framework Agent is a required reviewer.
- If user-facing behavior changes, the relevant Application or Domain Agent is
  a required reviewer.
- If data can be sensitive or persistent, Security and Privacy Agent is a
  required reviewer.
- If the change is user-visible, QA Automation Agent is a required reviewer.

### 4. Contract Draft

Required when more than one module or agent is involved:

```markdown
## Cross-Agent Contract

**Provider agent:** ...
**Consumer agent:** ...
**Interface/API:** ...
**Input shape:** ...
**Output shape:** ...
**State changes:** ...
**Errors:** ...
**Permissions:** ...
**Privacy/redaction:** ...
**Persistence:** ...
**Versioning/migration:** ...
**Tests required:** ...
```

No cross-boundary code should be merged without this contract.

### 5. Automation Flow Draft

Every implementation ticket must include deterministic use cases and automation
flows. Use the tracker in issue `#323`.

Automation flows must declare their execution environment: host-only, physical
Android device, iOS simulator, or Android Emulator with explicit opt-in.
Android Emulator/QEMU crashes are infrastructure failures. If a run reports
`qemu-system-aarch64 EXC_BAD_ACCESS / KERN_INVALID_ADDRESS`, agents must stop
that path, preserve the report, and switch to host-only checks or a physical
device. Retrying the same emulator loop is blocked unless the issue explicitly
accepts `AIRO_ALLOW_ANDROID_EMULATOR=true`.

Minimum format:

```markdown
## Deterministic Use Cases

### UC-001: <title>
**Actor:** ...
**Preconditions:** ...
**Trigger:** ...
**Happy path:** ...
**Alternate paths:** ...
**Failure paths:** ...
**Data created/updated/deleted:** ...
**Privacy expectations:** ...

## Automation Flow

### AUTO-001: <title>
**Given:** ...
**When:** ...
**Then:** ...
**Fixtures:** ...
**Mocks/stubs:** ...
**Assertions:** ...
**Cleanup:** ...
```

### 6. Implementation

Implementation rules:
- Keep framework code framework-shaped.
- Keep application code product-shaped.
- Do not duplicate framework logic inside feature screens.
- Do not add hidden network/model/tool behavior.
- Do not skip migration, deletion, or failure paths.
- Keep PRs scoped to the declared contract.

### 7. Cross-Agent Review

Required review checklist:
- Primary owner confirms behavior.
- Framework owner confirms boundary.
- Security owner confirms permissions and data handling.
- QA owner confirms automation flow.
- UI/domain owner confirms user journey where applicable.

### 8. QA Hardening

Before completion:
- happy path test exists
- at least one failure path test exists
- persistence and cleanup are verified
- tool traces and memory writes are asserted where relevant
- accessibility and timeout expectations are covered for UI
- device-only verification names the exact device/simulator/emulator used
- Android Emulator was not used unless the issue explicitly accepted
  `AIRO_ALLOW_ANDROID_EMULATOR=true`

### 9. Release Ready

Release Agent confirms:
- docs or ADR updated when contract changes
- migrations are safe
- focused local validation covers the change, documented with `[skip ci]` for
  iterative work
- remote CI/build checks were used only when required by branch protection,
  release/signing, artifact validation, or the issue risk profile
- rollback or disable path exists for risky features

### 10. GitHub Actions Cost Control

GitHub Actions minutes are shared project cost. Agents must avoid unnecessary
remote builds and must not wait on expensive artifact jobs when they are not
required to prove the slice.

Default validation order:
- Run the narrowest local checks that cover the touched contract: package
  tests, focused `flutter analyze`, formatting, docs completeness, scripts, or
  host-only smoke checks.
- Open PRs after local evidence is recorded. Do not trigger extra workflow
  re-runs unless a failed required check is relevant to the change.
- Use `[skip ci]` for local-only commits and direct release-line sync pushes
  when remote CI is not required and repository/branch policy permits it.
- Treat release, signing, Play upload, APK/AAB artifact, full Android matrix,
  emulator, and broad integration workflows as opt-in. Use them only when the
  issue, branch protection, or release owner requires them.
- If an expensive workflow starts accidentally, becomes redundant, or is only
  producing non-required artifacts, cancel it with `gh run cancel <run-id>`
  instead of waiting.
- If a bounded slice is complete but the parent issue has broader benchmark,
  physical-device, or release evidence remaining, merge the slice and record
  the remaining evidence as follow-up. Do not hold unrelated code open solely
  for non-required CI artifact builds.
- Close issues as soon as their bounded acceptance criteria are met. Do not
  keep completed issue slices open for optional CI, broad matrix runs, release
  artifacts, or physical-device evidence that can be tracked separately.

## Feature Packet Template

Agents should add this to a GitHub issue before coding:

```markdown
## Feature Packet

**Primary owner agent:** ...
**Review agents:** ...
**Layer:** Framework / Application / Mixed
**Sprint:** ...
**Parent roadmap:** ...

### Critical Agent Gate
...

### Cross-Agent Contract
...

### Deterministic Use Cases
...

### Automation Flow
...

### Implementation Boundaries
- Framework files:
- Application files:
- Tests:
- Docs:
- Verification environment:
```

## Merge Policy

Do not merge implementation PRs unless:
- Critical Agent gate is marked `Ready`.
- Primary owner is declared.
- Required review agents are listed.
- Cross-agent contract exists for mixed work.
- Deterministic use cases and automation flows exist.
- Focused local validation, required checks, or explicit test gaps are
  documented.
- Non-required expensive GitHub Actions runs are not left running.

## Delegation Prompt

Use this prompt when delegating to another agent:

```text
You are the <Agent Name> for issue #<number>. Before implementation, read
AGENTS.md and docs/agents/AGENT_POLICY.md. Identify your ownership boundary,
ask Critical Agent questions, draft the cross-agent contract if needed, and
write deterministic use cases plus automation flows. Do not implement code until
the feature packet is complete and reviewed.
```

## Related Documents

- [Agent Operating Rules](./RULES.md)
- [Agent Activation Sequence](./SEQUENCE.md)
- [Agent SDLC](./SDLC.md)
- [Sprint sequencing issue](https://github.com/DevelopersCoffee/airo/issues/322)
- [Automation-flow requirement](https://github.com/DevelopersCoffee/airo/issues/323)
