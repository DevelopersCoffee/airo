# Mobile UI Agent Tasks

**Context**: Airo shell chrome and navigation decisions need a shared mobile UI
governance layer before more feature screens keep evolving independently.

**Goal**: Document shell/header ownership, standards, and execution sequencing
for mobile UI work.

## Governance Deliverables

### 1. Mobile UI agent packet - [x] DONE

- [x] Define ownership boundaries for shell chrome, navigation, and shared
  mobile presentation
- [x] Document required issue inputs before implementation
- [x] Link the governing standards and ADR artifacts

### 2. Shell/header ADR - [x] DONE

- [x] Record the shell-versus-route ownership rule
- [x] Define when fullscreen and contextual headers are allowed
- [x] Capture the consequences and rollout expectations

### 3. Shared UI standards - [x] DONE

- [x] Define token, header, navigation, and asset governance rules
- [x] Clarify feature-team constraints versus shared-shell ownership
- [x] Provide verification expectations for follow-up UI work

### 4. Child implementation queue - [x] READY

- [x] `#398` header ownership consolidation
- [x] `#399` theme tokens and navigation centralization
- [x] `#400` shell asset registry and chrome hygiene

## Verification

- Governance docs exist under `docs/agents/mobile-ui-agent/`
- ADR exists under `docs/adr/`
- Standards doc exists under `docs/standards/`
- Agent index links to the Mobile UI Agent packet
- ADR index includes the new shell/header governance decision

## Notes

- This packet is governance-only. It intentionally does not implement the shell
  changes tracked by `#398`, `#399`, or `#400`.
- Future Mobile UI issues should update this task list as execution work lands.
