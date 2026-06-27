---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Wire agent chat to active offline model selection'
labels: 'agent/ai-llm, agent/mobile-ui, priority/P0, enhancement, on-device'
assignees: ''
---

## Feature Packet

**Primary owner agent:** agent/ai-llm
**Review agents:** agent/mobile-ui, agent/qa-testing
**Layer:** Mixed
**Sprint:** Offline LLM foundation
**Parent roadmap:** `.github/issues/OFFLINE_LLM_ROADMAP.md`

### Critical Agent Gate

**Problem:** Agent chat exposes multiple local model choices and a model
manager, but runtime execution still only honors Gemini Nano, one default
LiteRT package, or cloud fallback. Downloaded/active offline models do not
actually drive chat inference, which breaks the contract implied by the UI.

**User / actor:** End-user selecting or downloading an offline model for Airo
Agent chat.

**Framework or application layer:** Mixed. Shared selection/routing contract
crosses settings state, model library UI, and agent chat runtime.

**Owning agent:** agent/ai-llm

**Reviewing agents:** agent/mobile-ui, agent/qa-testing

**Impacted modules/files:**
- `app/lib/features/settings/presentation/screens/ai_models_screen.dart`
- `app/lib/features/agent_chat/presentation/screens/model_library_screen.dart`
- `app/lib/features/agent_chat/presentation/screens/chat_screen.dart`
- `app/lib/core/services/litert_lm_service.dart`
- `app/test/core/services/litert_lm_service_test.dart`
- `app/test/features/agent_chat/...` (new or updated)

**Open questions:**
- Which selected model should agent chat prefer when both a project-level
  assistant model and a downloaded active offline model exist?
- How do we degrade when a chosen offline model is not yet installed?

**Decision:** Ready

### Cross-Agent Contract

**Provider agent:** agent/ai-llm

**Consumer agent:** agent/mobile-ui

**Interface/API:**
- Shared persisted assistant model IDs for chat-safe local/cloud runtimes.
- LiteRT service entrypoint that can generate against a specific downloaded
  package instead of only a single compile-time default path.

**Input shape:**
- `assistantModelId: String`
- optional `OfflineModelInfo package`
- `prompt: String`

**Output shape:**
- Assistant response text or a deterministic fallback error message that
  explains the missing runtime/install state.

**State changes:**
- Selecting a downloaded model in model management can activate it for chat.
- Agent chat reads the same persisted selection contract.

**Errors:**
- Missing or uninstalled packages return a user-facing configuration message.
- Unsupported platforms do not crash and instead instruct the user to use cloud
  or an available local runtime.

**Permissions:** No new permissions.

**Privacy/redaction:** Local models remain local; cloud selection remains an
explicit user choice.

**Persistence:** SharedPreferences-based selection state only.

**Versioning/migration:** Backward compatible; old saved IDs still map to valid
assistant runtimes.

**Tests required:**
- Unit tests for model-path-aware LiteRT generation.
- Widget/service tests covering assistant selection fallback behavior.

### Deterministic Use Cases

#### UC-001: Downloaded offline model becomes active for chat
**Actor:** User
**Preconditions:** A compatible offline package is downloaded from AI Models.
**Trigger:** User sets the package as active, then opens Agent chat.
**Happy path:**
1. Settings persists the active offline model ID.
2. Agent chat resolves the same selection.
3. Sending a message routes through LiteRT using the selected package path.
4. The response is rendered without falling back to the generic "not wired"
   message.
**Failure paths:**
- If the file is missing, chat shows a deterministic install/configuration
  message and does not crash.

#### UC-002: Built-in cloud and Nano selections remain valid
**Actor:** User
**Preconditions:** Existing saved selection is `gemini-nano` or
`gemini-cloud`.
**Trigger:** User opens Agent chat after the routing change.
**Happy path:** Chat continues using the chosen runtime without migration work.
**Failure paths:** If Nano is unavailable, chat explains that another runtime
must be selected.

### Automation Flow

#### AUTO-001: Active offline selection routes agent chat through LiteRT
**Given:** Shared preferences contain an assistant selection for a downloaded
offline package and LiteRT client stubs return a response.
**When:** Agent chat sends a message.
**Then:** The selected package is passed to LiteRT generation and the returned
response replaces the streaming placeholder.
**Fixtures:** Fake shared preferences, fake LiteRT client.
**Mocks/stubs:** No real native model runtime required.
**Assertions:** Selected package path is used; fallback copy is not shown.
**Cleanup:** Reset shared preferences between tests.

### Implementation Boundaries
- Framework files:
  `app/lib/core/services/litert_lm_service.dart`
- Application files:
  `app/lib/features/settings/presentation/screens/ai_models_screen.dart`
  `app/lib/features/agent_chat/presentation/screens/model_library_screen.dart`
  `app/lib/features/agent_chat/presentation/screens/chat_screen.dart`
- Tests:
  `app/test/core/services/litert_lm_service_test.dart`
  `app/test/features/agent_chat/...`
- Docs:
  `.github/issues/offline-llm-11-agent-chat-offline-model-routing.md`
- Verification environment:
  host-only unit/widget tests
