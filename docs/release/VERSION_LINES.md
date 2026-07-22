# Airo V1 and V2 Version Lines

This document classifies the two Airo product lines so release branches,
APK artifacts, roadmap work, and support expectations stay unambiguous.

## Critical Agent Gate

**Problem:** Airo now has two product directions: the current monolithic app and
the modular APK/foundation architecture. Contributors need a shared naming and
branching model before release or architecture work continues.

**User / actor:** Release managers, framework agents, application agents, QA,
and Android build owners.

**Framework or application layer:** Mixed. V1 is an application release line;
V2 changes framework boundaries, package ownership, build variants, and feature
delivery.

**Owning agent:** Release and DevEx Agent.

**Reviewing agents:** Framework Agent, Application Agent, Mobile UI Agent, QA
Automation Agent, Security and Privacy Agent.

**Impacted modules/files:** Release documentation, architecture documentation,
Android build strategy, package boundaries, feature registry, CI release matrix.

**Base branch/worktree:** After the branch split, implementation work must start
from the matching base branch: `v1` for monolith work or `v2` for modular work.

**Open questions:** Exact Play Store package IDs, signing tracks, and whether
V2 ships as separate APK listings, app bundle dynamic delivery, or both.

**Decision:** Ready for documentation. Code and CI changes require a follow-up
Feature Packet before implementation.

## Release Line Summary

| Line | Product name | Version series | Primary branch | Purpose |
| --- | --- | --- | --- | --- |
| V1 | Airo Monolith | `1.x.y` | `v1` | Stable full-app line with all current monolithic functionality. |
| V2 | Airo Modular | `2.x.y` | `v2` | Modular foundation with platform and business-specific APKs. |

## V1: Monolithic Application

V1 is the conventional full Airo application. It keeps the existing super-app
shape where the host app bundles the broad set of supported product journeys.

**Market position:** Stable legacy/current-production line.

**Versioning:**
- Use semantic versions under `v1.x.y`.
- Keep patch releases compatible with existing V1 installs.
- Do not introduce modular architecture requirements into V1 patch releases.

**Branching:**
- `v1` is the long-lived base branch for the V1 monolith.
- Tags use immutable semantic version tags such as `v1.0.0`, `v1.1.0`, and
  `v1.2.0`.
- Hotfix branches should start from `v1` and use names like
  `hotfix/v1-crash-on-launch` or `codex/v1-crash-on-launch`.

**Artifact naming:**
- `airo-v1-full.apk`
- `airo-v1-full-arm64-v8a.apk`
- `airo-v1-full-armeabi-v7a.apk`
- `airo-v1-full-x86_64.apk`
- `airo-v1-full.aab`

**Allowed changes:**
- Critical bug fixes.
- Security and privacy fixes.
- Store compliance fixes.
- Low-risk UX and copy fixes.
- Dependency patches required by CI, Play policy, or platform compatibility.

**Blocked changes:**
- Feature extraction that changes package boundaries.
- New dynamic delivery or business APK architecture.
- Breaking storage, auth, routing, or navigation contracts.
- New feature families that increase APK size without explicit release approval.

## V2: Modular Application

V2 is the new modular Airo architecture. It separates reusable foundation code
from business modules so releases can target smaller APKs by user journey,
device class, or store listing.

**Market position:** Active modular platform line.

**Versioning:**
- Use semantic product release tags for the current product line. Airo TV tags
  use `airo-tv-v0.0.x`; full Airo tags use `v0.0.x` unless a release issue
  explicitly defines a product-specific prefix.
- The current Airo TV release train advances from `airo-tv-v0.0.4` to
  `airo-tv-v0.0.5`.
- Treat package contracts, feature registry APIs, and build target manifests as
  V2 compatibility surfaces.

**Branching:**
- Active modular release work starts from latest `origin/main`.
- Issue-scoped `codex/*` branches must start from `origin/main` and carry
  isolated implementation work before merge.
- Release candidates are cut from `origin/main` into point-in-time release
  branches such as `release/airo-tv-v0.0.5`.
- Tags use immutable semantic product tags such as `airo-tv-v0.0.5` and
  `v0.0.5`.

**Artifact naming:**
- `Airo-0.0.5-7-arm64.apk`
- `Airo-0.0.5-7-Play-Store.aab`
- `Airo-TV-0.0.5.apk`
- `Airo-TV-0.0.5-Play-Store.aab`
- `Airo-TV-0.0.5-macOS.zip`
- `Airo-TV-0.0.5-macOS.dmg`

**Allowed changes:**
- Feature registry and module manifest work.
- Platform-specific entrypoints and build flavors.
- Package extraction from `app/lib/features/` into `packages/`.
- Size-budget automation and APK split validation.
- Stable framework contracts for auth, storage, routing, media, AI, and UI.
- Business-module APKs that depend on the V2 foundation.

**Blocked changes:**
- Product modules reaching around framework contracts.
- V2-only package contracts merged into `v1`.
- Unversioned storage or permission changes.
- APK split changes without deterministic size and smoke validation.

## Branch Model

Use two long-lived base branches:

```text
origin/v1_bkp
  Archived pre-swap monolith reference branch; tags and historical state only

origin/main
  Current modular base branch; tags v2.x.y

origin/codex/v1-<task> or origin/hotfix/v1-<task>
  scoped legacy work branched from origin/v1_bkp

origin/codex/v2-<task> or origin/feat/v2-<task>
  scoped V2 modular work branched from origin/main
```

Use `main` as the active product base. Keep `origin/v1_bkp` only as a legacy
reference line when an issue explicitly requires pre-swap history. Branches still
represent code-line ownership; APK names, app IDs, flavors, and release
artifacts represent product SKUs.

## Cross-Agent Contract

**Provider agent:** Framework Agent for V2 foundation; Release and DevEx Agent
for branch/release policy.

**Consumer agent:** Application Agent, Mobile UI Agent, domain agents, Android
release owners.

**Interface/API:** Version-line naming, branch naming, tag naming, artifact
naming, and release eligibility.

**Input shape:** Feature Packet or release request declaring V1 or V2.

**Output shape:** Branch, tag, artifact, release note, and CI matrix entry using
the correct line prefix.

**State changes:** No runtime state changes from this policy. Future V2 work may
introduce storage migrations and must document them separately.

**Errors:** Misclassified work must be moved before merge. V2 architectural work
must not land on `v1`.

**Permissions:** No new runtime permissions from this policy.

**Privacy/redaction:** No user data is touched by this policy.

**Persistence:** Release metadata is persisted through git branches, tags,
release notes, and CI artifacts.

**Versioning/migration:** V1 remains `1.x.y`; V2 starts at `2.0.0`. Breaking
architecture changes belong in V2.

**Tests required:** Documentation checks for this policy; follow-up build work
requires APK size checks, smoke tests, and platform-specific release validation.

## Deterministic Use Cases

### UC-001: V1 hotfix classification

**Actor:** Release manager.

**Preconditions:** A bug affects the monolithic production app.

**Trigger:** A hotfix is requested.

**Happy path:** Work starts from `v1_bkp`, ships as `v1.x.y`, and produces
`airo-v1-full*` artifacts.

**Alternate paths:** If the fix requires V2 module boundaries, split the work:
minimal V1 fix plus separate V2 implementation.

**Failure paths:** If work starts from the wrong base branch or a stale branch,
stop and recreate the branch from `v1_bkp`.

**Data created/updated/deleted:** Release notes, tag, and APK artifacts only.

**Privacy expectations:** No privacy behavior changes unless the hotfix is
explicitly security-related.

### UC-002: V2 modular feature classification

**Actor:** Framework or domain agent.

**Preconditions:** A business module or platform APK is planned.

**Trigger:** V2 modular implementation starts.

**Happy path:** Work starts from latest `origin/main` or an approved V2
integration branch based on `main`, declares framework/application contracts, and
ships under `v2.x.y`.

**Alternate paths:** If the module can ship inside V1 without architecture
changes, classify it as a V1 application feature only after release approval.

**Failure paths:** If module code bypasses framework contracts or increases V1
APK size, block merge.

**Data created/updated/deleted:** Package manifests, feature registry entries,
CI artifacts, and release notes.

**Privacy expectations:** Module-specific data and permissions require Security
and Privacy Agent review.

## Automation Flow

### AUTO-001: Version-line docs check

**Given:** A release PR changes release docs, build scripts, or artifact names.

**When:** Documentation checks run.

**Then:** The PR must reference either V1 or V2 and use the matching branch,
version, and artifact naming.

**Fixtures:** Markdown files under `docs/release/` and `docs/architecture/`.

**Mocks/stubs:** None.

**Assertions:** Links resolve; release-line table includes V1 and V2; artifact
examples include both monolith and modular outputs.

**Cleanup:** None.

### AUTO-002: Future APK matrix validation

**Given:** V2 build flavors are implemented.

**When:** CI builds release artifacts.

**Then:** V1 produces full monolith artifacts, while V2 produces foundation and
business-specific APK artifacts with separate size budgets.

**Fixtures:** Platform build manifests and flavor configuration.

**Mocks/stubs:** Store signing credentials can be replaced with CI signing
stubs for validation.

**Assertions:** Artifact names include `airo-v1-` or `airo-v2-`; V2 module APKs
do not bundle unrelated heavy dependencies.

**Cleanup:** Remove temporary build artifacts after size reports are uploaded.

## Migration Checklist

- [ ] Create or confirm `v1` from the chosen V1 production baseline.
- [ ] Create or confirm `v2` from the chosen V2 modular baseline.
- [ ] Keep existing `v1.x.y` tags immutable.
- [ ] Confirm whether any existing point-release branch should be retained as an
      archive or folded into `v1`.
- [ ] Keep V2 architecture work on `v2` or scoped branches created from `v2`.
- [ ] Stop using `main` as the base branch for V1/V2 implementation after the
      split is complete.
- [ ] Update CI artifact names to include `airo-v1-` or `airo-v2-`.
- [ ] Add APK size budgets per V1/V2 artifact.
- [ ] Add release notes sections for V1 maintenance and V2 modular milestones.

## Related Documents

- [Release checklist](./RELEASE_CHECKLIST.md)
- [Release v1.0.0 summary](./RELEASE_v1.0.0_SUMMARY.md)
- [Modular super app sprint plan](../architecture/MODULAR_SUPER_APP_SPRINT_PLAN.md)
- [Model delivery and size guardrails](../architecture/MODEL_DELIVERY_AND_SIZE_GUARDRAILS.md)
- [Agent policy](../agents/AGENT_POLICY.md)
