# GGUF production readiness boundary

Status: **Ready for implementation**  
Date: 2026-07-30  
Owner: Framework Agent (`packages/core_ai`)  
Reviewers: Chief Security Officer, Chief QA Officer, Chief Performance Officer

## Critical Agent Gate

**Problem:** `ActiveModelService.loadModel` currently simulates loading and can
mark a GGUF model `ready` even though the native llama.cpp execution backend is
not bundled. This creates a false production-ready state and can lead to a
chat request failing only after the user has been told the model loaded.

**User / actor:** Airo users selecting a local GGUF model.

**Framework or application layer:** Framework runtime boundary in
`packages/core_ai`; no UI or platform-specific implementation is introduced.

**Owning agent:** Framework Agent.

**Reviewing agents:** Security, QA, and Performance reviewers.

**Base branch/worktree:** Confirmed from `origin/main`.

**Open questions:** Native llama.cpp FFI remains a separate backend milestone;
this change must not claim to implement it.

**Decision:** Production `loadModel` returns a structured unavailable failure
unless a real loader is registered. Test construction may inject a deterministic
simulated loader so lifecycle and planner tests remain independent of native
hardware.

## Contract and deterministic use cases

1. Production construction never reports a GGUF model as ready without a
   registered native loader.
2. Test construction can opt into deterministic simulated loading.
3. Existing unload, switch, progress, and metrics tests remain deterministic.
4. The error explicitly directs callers to the native backend/remote server
   setup instead of implying an OOM or successful load.

## Automation flow

Run the focused `active_model_service_test.dart` suite, the complete
`packages/core_ai` suite, formatting, `git diff --check`, and the device smoke
test confirming the Mind chooser does not advertise an unconfigured LiteRT
package.
