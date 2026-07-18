---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Warm up Gemini Nano on Chat Screen Load to Prevent First Prompt Latency'
labels: 'agent/ai-llm, priority/P0, enhancement, on-device, pixel9, platform-android'
assignees: ''
---

## Agent

**Agent:** agent/ai-llm, agent/mobile-ui

## Task Details

**Estimate (hours):** 8

**Priority:** P0

## Description

Users experience a significant cold-start delay (10-15 seconds) when submitting their first prompt using Gemini Nano on Android devices (e.g., Pixel 9). This happens because ML Kit GenAI model weights are lazy-loaded into RAM/GPU memory only upon the first inference request (`generateContent` or `generateContentStream`).

To resolve this issue and provide a premium, low-latency user experience, we need to implement model pre-warming (triggering model load in the background) when the Chat Screen loads.

### Proposed Solution
1. Add a `warmup()` method in `GeminiNanoService` (app layer service) and `GeminiNanoClient` (framework layer client) that triggers a lightweight warmup inference in the background.
2. In the native Kotlin implementation (`GeminiNanoPlugin.kt`), implement a warmup routine. Since ML Kit does not provide a direct warmup API, sending a dummy inference request (e.g., a prompt with whitespace `" "`) is the standard practice to force loading the weights into memory.
3. Automatically call this warmup method in `_initializeAI()` inside `chat_screen.dart` right after initializing the model.
4. Ensure the warmup run happens asynchronously without blocking the UI thread or interfering with user interactions.

---

## Critical Agent Gate

**Problem:** Users experience a cold-start delay of 10-15 seconds on their first prompt because Gemini Nano lazy-loads its 2.5GB model weights only when inference is requested.
**User / actor:** End-user starting a chat session on a Pixel 9 phone.
**Framework or application layer:** Mixed (Framework for the `warmup()` API in `core_ai`, Application for triggering it on `ChatScreen` load).
**Owning agent:** agent/ai-llm (Framework), agent/mobile-ui (Application/UI).
**Reviewing agents:** agent/qa-testing.
**Impacted modules/files:**
- `packages/core_ai/lib/src/llm/gemini_nano_client.dart`
- `packages/core_ai/lib/src/llm/llm_router_impl.dart`
- `app/lib/core/services/gemini_nano_service.dart`
- `app/lib/features/agent_chat/presentation/screens/chat_screen.dart`
- `app/android/app/src/main/kotlin/io/airo/app/GeminiNanoPlugin.kt`
**Open questions:** None. Warming up the model with a blank space is safe, private, and does not require internet access.
**Decision:** Ready

---

## Cross-Agent Contract

**Provider agent:** agent/ai-llm (Framework layer)
**Consumer agent:** agent/mobile-ui (Application/UI layer)
**Interface/API:** Expose `Future<bool> warmup()` in `GeminiNanoClient` and `GeminiNanoService`.
**Input shape:** None.
**Output shape:** `Future<bool>` indicating whether the warmup call was successfully issued and processed.
**State changes:** Triggers native initialization and triggers a lightweight/dummy prompt to load the 2.5GB model weights into device memory.
**Errors:** Returns `false` or logs warning if device is not supported or if initialization/warmup fails. Does not throw runtime errors that crash the app.
**Permissions:** Standard local-first permissions.
**Privacy/redaction:** None (the dummy prompt contains no user data).
**Persistence:** None.
**Versioning/migration:** Backward compatible.
**Tests required:** Unit tests verifying `warmup()` invokes the method channel.

---

## Deterministic Use Cases

### UC-001: Model Pre-warming on Chat Load
**Actor:** User
**Preconditions:** Gemini Nano is supported on the Pixel 9 device, and the user opens the Chat screen.
**Trigger:** Chat screen loads and `initState()` executes.
**Happy path:**
1. Chat Screen initializes and checks model support.
2. `GeminiNanoService.warmup()` is invoked in the background.
3. The method channel calls the native plugin, which triggers a fast dummy inference.
4. The model weights are loaded into RAM/GPU memory.
5. The user types their first prompt and clicks Send.
6. The prompt executes with zero cold-start delay (<1-2 seconds instead of 10-15 seconds).
**Alternate path:**
- If the model is already warmed up/initialized, the native method returns immediately.
**Failure path:**
- If device is not supported or has low memory, the warmup fails gracefully with a logged warning, allowing the app to fall back to the cloud/mock or proceed normally without crashing.

---

## Automation Flow

### AUTO-001: Verify Pre-warming Invocation
**Given:** An Android device that supports Gemini Nano.
**When:** The `ChatScreen` is initialized.
**Then:** `GeminiNanoService.warmup()` is invoked, executing a method channel call to the native `GeminiNanoPlugin`.
**Fixtures:** Mock MethodChannel for `com.airo.gemini_nano`.
**Mocks/stubs:** Mock `isAvailable` returning `true`, mock `initialize` returning `true`, and mock `generateContent` returning a blank string for warmup requests.
**Assertions:** Verify that `generateContent` was invoked with prompt `" "` or the designated warmup prompt during initialization.

---

## Acceptance Criteria

- [ ] Add `warmup()` method to `GeminiNanoClient` (in `core_ai` package) that calls a native method channel.
- [ ] Add `warmup()` method to `GeminiNanoService` (in `app` core services) to expose warmup capabilities to the application layer.
- [ ] Implement `warmup` handler in native Android `GeminiNanoPlugin.kt` that triggers model loading (using a blank space prompt `" "` or official warmup hooks if available).
- [ ] Call `_geminiNano.warmup()` in `_initializeAI()` in `chat_screen.dart` immediately after a successful initialization.
- [ ] Ensure that pre-warming is non-blocking and executes in the background.
- [ ] Verify that first-prompt latency on supported devices is reduced to normal inference speeds (< 2s).
- [ ] Unit tests for `warmup()` method in `GeminiNanoClient`.

## CI Checklist

- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added for warmup functionality

## Files to Modify

```
packages/core_ai/lib/src/llm/gemini_nano_client.dart
packages/core_ai/lib/src/llm/llm_router_impl.dart
app/lib/core/services/gemini_nano_service.dart
app/lib/features/agent_chat/presentation/screens/chat_screen.dart
app/android/app/src/main/kotlin/io/airo/app/GeminiNanoPlugin.kt
```

## Dependencies

- None (Independent performance improvement)

## Release Note Required?

yes - Pre-warm Gemini Nano on app/chat load to eliminate cold-start latency for the first prompt.
