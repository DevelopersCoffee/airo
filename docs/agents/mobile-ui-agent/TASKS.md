# Mobile UI Agent Tasks

**Context**: The initial governance packet exists, but the next UI/UX phase
needs tighter standards around native-first shell patterns, top-space
efficiency, centralized asset management, and narrow-screen overflow behavior.

**Goal**: Keep future UI work aligned to one shared shell contract so feature
teams stop re-solving headers, navigation, and branding inside screen files.

## Completed Governance Foundation

### 1. Mobile UI agent packet - [x] DONE

- [x] Ownership boundaries defined for shell chrome, navigation, and shared
  mobile presentation
- [x] Required issue inputs documented before implementation
- [x] Governing standards and ADR artifacts linked

### 2. Shell/header ADR - [x] DONE

- [x] Shell-versus-route ownership rule recorded
- [x] Fullscreen and contextual header cases defined
- [x] Consequences and rollout expectations captured

### 3. Shared UI standards - [x] DONE

- [x] Token, header, navigation, and asset governance rules defined
- [x] Feature-team constraints versus shared-shell ownership clarified
- [x] Verification expectations for follow-up UI work documented

## Current Phase Work

### 4. Native-first header and chrome standards - [ ] PLANNED

- [ ] remove duplicate global/local/native header stacking
- [ ] define compact action budgets and overflow rules
- [ ] audit routes that still consume unnecessary top space
- [ ] `#417` single-header and compact chrome execution

### 5. Navigation and unified configuration - [ ] PLANNED

- [ ] keep primary navigation in one shared destination model
- [ ] define when bottom nav, navigation rail, drawer, or hamburger applies
- [ ] prevent feature-local destination invention
- [ ] `#418` shared navigation overflow and hamburger policy execution

### 6. Asset and visual system hygiene - [ ] PLANNED

- [ ] centralize shell asset references
- [ ] tighten token usage and spacing consistency
- [ ] remove decorative shell clutter that does not improve task completion
- [ ] `#416` shell asset and density hygiene execution

### 7. Verification rollout - [ ] PLANNED

- [ ] add deterministic route/header ownership tests
- [ ] add overflow navigation and asset registry verification
- [ ] split execution into focused child issues
- [ ] `#415` parent rollout tracking and sequencing

## Verification

- Governance docs exist under `docs/agents/mobile-ui-agent/`
- ADR exists under `docs/adr/`
- Standards doc exists under `docs/standards/`
- Agent index links to the Mobile UI Agent packet
- ADR index includes the shell/header governance decision
- Phase plan exists for the current UI/UX rollout

## Notes

- The Mobile UI Agent remains the canonical UI/UX owner for shell behavior.
- Do not create a second parallel UI ownership packet unless the repo-wide
  ownership map changes.
- Current phase issue queue: `#415`, `#417`, `#418`, `#416`
