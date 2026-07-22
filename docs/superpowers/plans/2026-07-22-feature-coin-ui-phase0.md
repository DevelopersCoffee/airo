# Implementation Plan: feature_coin UI Phase 0

## Overview

Implement the deferred `feature_coin` presentation slice on the already-merged vault platform/session foundation. The work stays package-first, then wires the tested vault gate into the app Money branch and corrects the stale platform doc comment.

## Architecture Decisions

- Use summary aggregation for the vault home screen so no list render requires a DEK.
- Model selected records with a typed `VaultRecordRef` because bank/card/document records use nickname and PAN uses id.
- Keep screen security behind an injectable service so native calls are testable without platform channels.
- Keep forms explicit per record type rather than introducing a generic form builder for four small schemas.
- Wire app shell routing only after the package UI is tested; use `/money/vault` under the existing Money branch.

## Task List

### Phase 1: Foundation

- [ ] Task 1: Add typed UI refs, summary aggregation, and screen-security service.
- [ ] Task 2: Add lock gate and grouped home list widgets.

### Checkpoint: Foundation

- [ ] `cd packages/feature_coin && flutter test` covers lock/home behavior.

### Phase 2: Record Interaction

- [ ] Task 3: Add masked detail sheet with reveal/copy for sensitive fields.
- [ ] Task 4: Add add/edit forms for bank account, PAN card, credit card, and secure document.

### Checkpoint: Core Flow

- [ ] Widget tests prove masked default, reveal-on-demand, copy delegation, and validation errors.

### Phase 3: Cleanup

- [ ] Task 5: Export UI surface and fix the stale platform key-manager doc comment.
- [ ] Task 6: Wire `/money/vault`, replace stale `airomoney` app dependency, and run focused validation.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Platform-channel calls break widget tests | Medium | Use injectable screen-security and auth seams. |
| Sensitive data leaks into list/provider state | High | Home screen uses summaries only; full records are local detail state. |
| PAN routing assumes nickname | Medium | Use `VaultRecordRef.panCard(id)` everywhere. |
| Form scope expands into attachments/reset | Medium | Keep attachments/reset out of Phase 0 UI. |

## Open Questions

- Physical-device verification is still needed for native screenshot-blocking and real biometric prompt UX.
