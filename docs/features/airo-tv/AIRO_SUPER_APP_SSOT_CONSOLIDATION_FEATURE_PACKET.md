# Airo Super-App / Aika Stream SSOT Consolidation Feature Packet

## Feature Packet

**Primary owner agent:** Chief Architect  
**Review agents:** Media Intelligence Architect, Aika Stream Flutter Architect, Chief QA Officer, Chief Documentation Officer, Chief Release/DevOps Officer  
**Layer:** Mixed — framework contracts plus application-shell composition  
**Sprint:** SSOT consolidation planning  
**Parent roadmap:** Super-app + modular-app platform alignment

### Critical Agent Gate

**Problem:** Airo and Aika Stream already share parts of the IPTV stack, but they do
not share one product-composition contract. Startup, feature registration,
settings composition, navigation composition, and TV dependency shaping are
owned in different places. That allows Aika Stream work to diverge from Airo and
forces manual duplication when a shared IPTV setting or menu option changes.

**User / actor:** Platform engineers, Aika Stream feature engineers, release
engineers, and users who expect the same IPTV capabilities to appear in both
the super-app and the TV app without regression.

**Framework or application layer:** Mixed. Shared shell/module contracts are
framework-level. Mobile and TV shell composition remains application-level.

**Owning agent:** Chief Architect.

**Reviewing agents:** Media Intelligence Architect (`feature_iptv` contracts),
Aika Stream Flutter Architect (TV rendering and shell adoption), Chief QA Officer
(no-break migration proof), Chief Documentation Officer (architecture and ADR
record), Chief Release/DevOps Officer (app-shell and manifest strategy).

**Impacted modules/files:** `app/` entrypoints and shell contracts,
`packages/feature_iptv`, future `core_product_shell` and IPTV split packages,
future standalone app shells, build/release docs, route/startup/nav/settings
tests.

**Base branch/worktree:** Yes — analysis performed in clean worktree
`codex/ssot-analysis-origin-main` created from fetched `origin/main` at
`e14eaa70`.

**Open questions:**

- Should `app/` remain the long-term super-app shell path or eventually become
  `apps/airo_super/`?
- Should audio settings be part of the shared IPTV settings contract or stay
  super-app-only unless TV intentionally exposes them?
- Should `packages/feature_iptv` remain the public compatibility façade name
  after the split?

**Decision:** Ready for architecture approval; not ready for implementation
until the package boundary and compatibility plan are accepted.

### Cross-Agent Contract

**Provider agent:** Chief Architect + Media Intelligence Architect  
**Consumer agent:** Aika Stream Flutter Architect, super-app shell owners, release
tooling  
**Interface/API:** Shared product-shell manifest and shared IPTV composition
contracts  
**Input shape:**

- `AppProfile` with enabled module ids and shell capabilities
- `AppModule` with routes, startup tasks, and provider overrides
- `IptvNavigationDestination` list
- `IptvSettingsSectionDescriptor` list

**Output shape:**

- super-app shell renders shared IPTV contracts in mobile form
- TV shell renders shared IPTV contracts in TV form
- both products adopt shared settings/menu changes from one source

**State changes:** No planned storage-key or route-id migration in the first
SSOT slice. Existing IPTV preferences, source data, recent history, and guide
settings remain owned by shared providers.

**Errors:** A shell missing a required module or unsupported profile should fail
at composition/validation time, not silently omit shared behavior.

**Permissions:** No new permissions introduced by the planning slice.

**Privacy/redaction:** No data collection changes. IPTV source and preference
data remain under existing shared provider/storage rules.

**Persistence:** Existing `SharedPreferences` and repository keys remain stable
through the first migration phases.

**Versioning/migration:** Additive. New shared contracts are introduced before
legacy app-owned definitions are removed.

**Tests required:** Shared nav/settings renderer tests, provider/storage
regression tests, route/startup assembly tests, and shell smoke validation.

### Deterministic Use Cases

#### UC-001: Shared IPTV setting appears in both shells

**Actor:** Aika Stream feature engineer  
**Preconditions:** IPTV settings are declared in the shared settings-section
manifest.  
**Trigger:** Add or change one shared IPTV setting section.  
**Happy path:** Airo mobile settings and Aika Stream settings both render the
updated option through their own adapters without duplicating the setting
definition.  
**Failure paths:** A setting is added only to one shell-specific screen or
requires editing two different source lists.  
**Data created/updated/deleted:** None beyond the existing setting state.  
**Privacy expectations:** No new data collection.

#### UC-002: Shared IPTV navigation destination appears in both shells

**Actor:** Platform engineer  
**Preconditions:** IPTV navigation destinations are declared once in shared
contracts.  
**Trigger:** Add, rename, or reorder a shared IPTV destination.  
**Happy path:** The mobile drawer and TV rail both reflect the same destination
set and semantic labels through their own renderers.  
**Failure paths:** One shell still uses a local hardcoded menu.  
**Data created/updated/deleted:** None.  
**Privacy expectations:** No new data collection.

#### UC-003: Aika Stream modular work is adopted by the super-app without breakage

**Actor:** Aika Stream feature engineer  
**Preconditions:** Shared IPTV behavior lives in shared contracts/packages;
shell-specific widgets remain adapters only.  
**Trigger:** Implement a shared IPTV capability or preference in the TV-focused
packages.  
**Happy path:** The super-app can consume the same shared contract without
manual app-layer duplication or route/startup regressions.  
**Failure paths:** The feature depends on TV-only shell code or app-owned
registry contracts.  
**Data created/updated/deleted:** Existing shared IPTV state only.  
**Privacy expectations:** Existing privacy rules remain unchanged.

### Automation Flow

#### AUTO-001: Shared composition contract parity

**Given:** Shared IPTV navigation and settings manifests, mobile renderer,
TV renderer  
**When:** Focused widget tests run  
**Then:** Both shells render from the same descriptors, and shell-local UI is
adapter-only  
**Fixtures:** Shared destination/section fixtures  
**Mocks/stubs:** Standard Riverpod/provider test doubles only  
**Assertions:** No shell reads from a private hardcoded destination/section list
for shared IPTV behavior  
**Cleanup:** None

#### AUTO-002: No-break provider/storage regression

**Given:** Existing IPTV shared providers and persisted settings  
**When:** Focused provider tests run after contract extraction  
**Then:** Storage keys, defaults, and route compatibility remain unchanged  
**Fixtures:** Existing shared preference and repository fixtures  
**Mocks/stubs:** Shared preferences/repository test fakes  
**Assertions:** Existing persisted settings still resolve correctly  
**Cleanup:** Clear test stores

#### AUTO-003: Shell profile composition

**Given:** App profiles, module registry, and shell startup tasks  
**When:** Super-app and TV shell smoke tests run  
**Then:** Each shell resolves the expected routes, overrides, and startup tasks
through shared contracts  
**Fixtures:** Profile fixtures for super-app and TV app  
**Mocks/stubs:** Startup task fakes and shell capability fakes  
**Assertions:** Shared composition no longer depends on `app/`-owned registry
logic only  
**Cleanup:** None

### Implementation Boundaries

- **Framework files:** shared shell registry/profile contracts; shared IPTV
  manifests; compatibility façade strategy; route/startup composition
- **Application files:** super-app shell, TV shell, mobile settings renderer,
  TV settings renderer, mobile drawer, TV rail
- **Tests:** focused widget/provider/route/startup tests only
- **Docs:** feature packet, ADR, migration blueprint, build-shell guidance
- **Verification environment:** local worktree validation only; no remote CI
  required for planning artifacts

## Target End State

### Shared contracts

- one module/app-profile registry contract
- one IPTV navigation manifest
- one IPTV settings-section manifest
- one shared IPTV core state layer

### Shell-specific adapters

- mobile drawer and settings list remain mobile-specific renderers
- TV rail and split-pane settings remain TV-specific renderers
- startup branches remain profile-specific where required

### Packaging target

- `core_product_shell`
- `feature_iptv_core`
- `feature_iptv_mobile`
- `feature_iptv_tv`
- `feature_iptv` as temporary compatibility façade
- eventual `apps/airo_super` and `apps/airo_tv`

## Phased Migration Contract

### Phase 1: Extract shared shell contracts

- move feature/module registry out of `app/`
- introduce `AppProfile`, `AppModule`, `ModuleRegistry`
- preserve current behavior

### Phase 2: Shared nav/settings descriptors

- create shared IPTV navigation descriptor list
- create shared IPTV settings-section descriptor list
- rewire current Airo and Aika Stream renderers

### Phase 3: Split `feature_iptv`

- core shared logic to `feature_iptv_core`
- mobile adapters to `feature_iptv_mobile`
- TV adapters to `feature_iptv_tv`
- retain `feature_iptv` compatibility façade

### Phase 4: First-class app shells

- introduce standalone TV shell
- move away from copied TV manifest strategy
- keep legacy entrypoints until parity is proven

## References

- `tasks/ssot_airo_airo_tv_gap_analysis.md`
- `tasks/ssot_airo_airo_tv_architecture_blueprint.md`
- `tasks/ssot_airo_airo_tv_todo.md`
- `docs/agents/AGENT_POLICY.md`
- `docs/agents/COUNCIL.md`
- `docs/features/airo-tv/PRODUCT_PROFILE_MANIFEST_SCHEMA.md`
- `docs/features/airo-tv/PROFILE_NAVIGATION_MANIFESTS.md`
