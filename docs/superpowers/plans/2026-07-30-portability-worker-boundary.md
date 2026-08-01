# Airo Mind portability serialization worker boundary

Status: **Ready for implementation**  
Date: 2026-07-30  
Owner: Flutter Architect / Airo Mind application layer  
Reviewers: Chief Performance Officer, Chief QA Officer, Chief Documentation Officer

## Critical Agent Gate

**Problem:** The Airo Mind portability screen performs JSON parsing and
serialization directly in a presentation file. The release worker-policy gate
rejects this boundary because chat history and backup payloads can grow beyond
the UI-safe size.

**User / actor:** Airo Mind users exporting or importing encrypted local
configuration and chat history.

**Framework or application layer:** Application-layer portability workflow,
with a reusable codec kept under `app/lib/core/portability`.

**Owning agent:** Flutter Architect / Airo Mind application owner.

**Reviewing agents:** Chief Performance Officer and Chief QA Officer; the
security posture of the existing encrypted backup service is preserved.

**Impacted modules/files:**

- `app/lib/features/settings/presentation/screens/airo_portability_screen.dart`
- `app/lib/core/portability/airo_portability_codec.dart`
- portability unit tests
- `scripts/check-worker-offload-policy.sh` validation

**Base branch/worktree:** Confirmed from `origin/main`: yes.

**Open questions:** None. The codec remains product-local and does not change
the encrypted backup envelope or its public format.

**Decision:** Ready.

## Contract and deterministic use cases

1. A valid versioned chat-history string yields only its `entries` list.
2. Missing, malformed, or non-map history yields `null` without throwing from
   the screen workflow.
3. Restored payloads serialize with the existing schema version and entries.
4. The presentation screen contains no direct JSON parsing or serialization.
5. Existing encrypted backup round trips remain byte-compatible at the
   payload-schema level.

## Automation flow

Run the portability codec tests, the worker-offload policy test, the focused
settings tests, `git diff --check`, and the release merge-readiness test.
