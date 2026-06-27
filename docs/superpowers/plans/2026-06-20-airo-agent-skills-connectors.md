# Airo Agent Skills and Connectors v2 Plan

**Date:** 2026-06-20

**Goal:** Bring the Google AI Edge Gallery style Agent Skills experience into Airo: skill manager, enabled skills, on-device model skill selection, native connector execution, and visible action traces in chat. The first end-to-end connector should be calendar read/create because it proves permissions, private local data access, multi-step tool use, and final natural-language response.

**Current Airo baseline:** `agent_chat` already has deterministic intent parsing, a small `ToolRegistry`, GoRouter navigation, Gemini Nano fallback chat, and Gallery-inspired prompt cards. That is useful but not the same architecture as Gallery skills. The v2 work should add a real skill runtime between chat and tools.

## Product Shape

Build one Airo feature called **Agent Skills** inside the Assistant tab.

- Chat input stays the main control surface.
- A `Skills` chip opens a Manage Skills sheet.
- Built-in skills are shipped with Airo.
- User-installed skills can come later from URL/local import after the native runtime is safe.
- Every enabled skill declares required capabilities such as `calendar.read`, `calendar.write`, `notifications.schedule`, `location.read`, `web.fetch`, or `route.open`.
- The model sees only skill names/descriptions until it chooses a skill.
- The app loads full skill instructions only after selection.
- Native connector calls are permission-gated and app-owned. The LLM never gets direct OS access.

## Architecture

### 1. Skill Package Model

Add a package format that is compatible with the Gallery mental model but native to Airo:

```text
calendar-today/
  SKILL.md
```

`SKILL.md` contains YAML frontmatter plus instructions:

```yaml
---
id: calendar-today
name: calendar-today
description: Read today's calendar events and summarize the user's schedule.
version: 1.0.0
author: Airo
runtime: native
capabilities:
  - calendar.read
tools:
  - get_current_date_time
  - read_calendar_events
---

# Calendar Today

Use this when the user asks about today's schedule, meetings, agenda, or calendar.
First call `get_current_date_time`.
Then call `read_calendar_events` with `date` in YYYY-MM-DD.
Summarize events by time. If no events exist, say there are no events scheduled.
```

Add these Dart models:

- `AgentSkillManifest`
- `AgentSkill`
- `SkillCapability`
- `SkillRuntime`
- `SkillSource` (`builtIn`, `local`, `remote`)
- `SkillInstallState`

Recommended location:

- `app/lib/features/agent_chat/domain/models/agent_skill.dart`
- `app/lib/features/agent_chat/domain/services/skill_manifest_parser.dart`
- `app/test/features/agent_chat/domain/services/skill_manifest_parser_test.dart`

### 2. Skill Repository

Add a repository that returns enabled built-in skills first.

Phase 1 should avoid remote/community installation. Remote skills introduce supply-chain and prompt-injection risk, so they should be behind a later review gate.

Recommended files:

- `app/lib/features/agent_chat/domain/repositories/agent_skill_repository.dart`
- `app/lib/features/agent_chat/data/repositories/built_in_agent_skill_repository.dart`
- `app/lib/features/agent_chat/data/built_in_skills/calendar_today.dart`
- `app/lib/features/agent_chat/data/built_in_skills/create_calendar_event.dart`

Store user enable/disable state with the app's existing local persistence pattern once that is clear. If no stable app storage exists, start with an in-memory repository plus tests, then persist in the next task.

### 3. Connector Registry

Add a separate connector layer. This is the main difference from the current `ToolRegistry`.

`ToolRegistry` currently routes known intents to screens or simple deterministic responses. Connector registry should execute app-owned native operations:

```dart
abstract interface class AgentConnector {
  String get name;
  Set<SkillCapability> get requiredCapabilities;
  Future<ConnectorResult> execute(Map<String, dynamic> arguments);
}
```

Built-in connectors for phase 1:

- `get_current_date_time`: no permission, returns local date/time/timezone.
- `read_calendar_events`: requires `calendar.read`, returns normalized events for a date.
- `create_calendar_event`: requires `calendar.write`, creates or opens an event creation flow.
- `open_route`: requires `route.open`, navigates to an Airo route.

Recommended files:

- `app/lib/features/agent_chat/domain/services/agent_connector.dart`
- `app/lib/features/agent_chat/domain/services/agent_connector_registry.dart`
- `app/lib/features/agent_chat/data/connectors/date_time_connector.dart`
- `app/lib/features/agent_chat/data/connectors/calendar_connector.dart`

### 4. Calendar Connector

Use a real calendar plugin for mobile builds.

Preferred package for read and write: `device_calendar`.

Reason: it supports requesting calendar permissions, retrieving calendars, retrieving events, adding/updating/deleting events, recurring events, reminders, attendees, and timezone-aware start/end dates.

Alternative for create-only flows: `add_2_calendar`.

Reason: it launches the native calendar app for user confirmation and does not need special permissions by default for the basic create flow, but it is not enough for "check my schedule" because Airo must read events.

Required platform work:

- Android: add `READ_CALENDAR` and `WRITE_CALENDAR` to `AndroidManifest.xml`.
- iOS: add `NSCalendarsUsageDescription` and `NSCalendarsFullAccessUsageDescription` to `Info.plist`.
- Review the current `app/pubspec.yaml` mode. It is currently SPM-oriented and stubs several native packages. Calendar support must be validated on Android first, then iOS with the actual plugin rather than a stub.

Safety behavior:

- Ask permission only when a calendar skill first runs.
- Show a native confirmation before creating or modifying events.
- Do not send raw event bodies through cloud AI fallback.
- If on-device Gemini Nano is unavailable, connector summaries must be deterministic or use a privacy-safe local template.

### 5. Skill Orchestrator

Add an orchestrator that turns a user message into a bounded tool loop:

```text
user prompt
  -> enabled skill summaries
  -> model chooses skill or says no skill
  -> app loads selected SKILL.md
  -> model emits one JSON action
  -> app validates tool name and schema
  -> app executes connector
  -> model receives connector result
  -> repeat until final response or max steps
```

Use `LLMJsonParser` for structured responses. Do not rely on free-form text parsing.

Suggested JSON contract from model to app:

```json
{
  "type": "tool_call",
  "skill_id": "calendar-today",
  "tool": "read_calendar_events",
  "arguments": {
    "date": "2026-06-20"
  }
}
```

Final response:

```json
{
  "type": "final",
  "message": "You have two events today: 10:00 AM Standup and 3:00 PM Design review."
}
```

Guardrails:

- Max 4 tool steps per user prompt.
- Tool must be declared by the selected skill.
- Tool arguments must validate against a local schema.
- Connector must have granted capabilities.
- Any write/delete/send action requires explicit user confirmation.
- Remote skill instructions cannot override these runtime rules.

Recommended files:

- `app/lib/features/agent_chat/domain/services/agent_skill_orchestrator.dart`
- `app/lib/features/agent_chat/domain/models/agent_action_trace.dart`
- `app/test/features/agent_chat/domain/services/agent_skill_orchestrator_test.dart`

### 6. Chat UI

Match the Gallery interaction but keep Airo visual style:

- Add `Skills` chip beside the input.
- Add a plus menu later for import URL/local once remote security is ready.
- Add action trace cards in the message list:
  - Loaded skill: `calendar-today`
  - Executed: `get_current_date_time`
  - Executed: `read_calendar_events` with redacted/short parameters
  - Final response
- Add Manage Skills sheet:
  - Search
  - Built-in skills section
  - Enable all/disable all
  - Per-skill capability badges
  - Permission state (`Allowed`, `Needs permission`, `Denied`)
  - View details

Recommended files:

- `app/lib/features/agent_chat/presentation/widgets/manage_skills_sheet.dart`
- `app/lib/features/agent_chat/presentation/widgets/skill_action_trace_card.dart`
- `app/lib/features/agent_chat/presentation/widgets/skill_chip.dart`
- Modify `app/lib/features/agent_chat/presentation/screens/chat_screen.dart`

### 7. System Prompt Strategy

The system prompt should be assembled by code, not hand-edited in a settings modal.

Use three layers:

1. Fixed runtime rules:
   - choose skills silently
   - output JSON only for tool steps
   - never invent connector results
   - do not claim actions were performed unless the app returned success
2. Enabled skill summaries:
   - `id`, `name`, `description`, declared tools
3. Selected skill instructions:
   - loaded only after `load_skill` equivalent

This keeps Gemini Nano context small and reduces prompt injection risk from skill text.

### 8. Initial Built-In Skills

Ship these first:

- `calendar-today`: check today's schedule.
- `calendar-date`: check schedule for a specific date.
- `create-calendar-event`: create event after confirmation.
- `schedule-notification`: use existing notification dependency for reminders.
- `open-airo-feature`: route to Money, Quest, Beats, Games, Stream, Reader.

After calendar is stable:

- `receipt-to-split`: OCR receipt, parse locally, open Split Bill.
- `meeting-minutes`: record/import audio, transcribe, summarize, create follow-up tasks.
- `daily-routine`: generate plan and optionally create calendar blocks.

## Implementation Tasks

### Task 1: Skill Domain and Parser

- [x] Add `AgentSkill` domain model.
- [ ] Parse YAML frontmatter and markdown body.
- [ ] Validate required fields and kebab-case IDs.
- [ ] Unit test valid and invalid `SKILL.md` files.

### Task 2: Built-In Skill Repository

- [x] Add in-memory built-in skills.
- [x] Add enable/disable state.
- [x] Expose enabled skill summaries for prompts.
- [ ] Unit test filtering, search, enable all, disable all.

### Task 3: Connector Registry

- [x] Add `AgentConnector` interface.
- [x] Add date/time connector.
- [x] Add fake calendar connector for tests.
- [x] Unit test connector dispatch and schema validation.

### Task 4: Calendar Native Integration

- [ ] Add calendar package to mobile pubspec after validating build mode.
- [ ] Add Android/iOS permissions.
- [ ] Implement permission request/status adapter.
- [ ] Implement read events for a date.
- [ ] Implement create event with confirmation.
- [ ] Add unit tests around adapter using fake connector.
- [ ] Add one device smoke test for Android calendar read.

### Task 5: Skill Orchestrator

- [ ] Build skill-selection prompt from enabled skill summaries.
- [ ] Parse model JSON with `LLMJsonParser`.
- [x] Execute bounded tool loop.
- [x] Record `AgentActionTrace` for UI.
- [x] Fall back to existing `IntentParser` for simple route commands.
- [ ] Unit test no-skill, one-tool, multi-tool, denied-permission, malformed-JSON, and max-step cases.

### Task 6: Chat UI

- [x] Add Skills chip to input area.
- [x] Add Manage Skills sheet.
- [x] Add action trace cards.
- [x] Wire orchestrator before normal Gemini chat fallback.
- [ ] Add widget tests for skill sheet and trace rendering.

### Task 7: Remote/Community Skills Later

- [ ] Add import from URL only after package verification exists.
- [ ] Pin allowed file types and max size.
- [ ] Require user review of capabilities before enabling.
- [ ] Store source URL, version, checksum, install date.
- [ ] Disable JS/WebView runtime until sandboxing, CSP, and secret handling are explicitly designed.

## Acceptance Criteria

Calendar demo should work like this:

1. User: "Check my schedule for today."
2. Airo selects `calendar-today`.
3. Airo asks calendar permission if needed.
4. Airo action card shows:
   - Load `calendar-today`
   - Execute `get_current_date_time`
   - Execute `read_calendar_events` with `{ "date": "YYYY-MM-DD" }`
5. Airo responds with a concise schedule summary or "No events scheduled."
6. If permission is denied, Airo explains that calendar access is needed and offers to open settings.
7. No calendar data leaves the device unless the user explicitly chooses a cloud mode later.

## Key Decision

Do not expose arbitrary "connectors" directly to the LLM. Expose only app-owned, typed connector methods through a registry, with capability checks, argument validation, permission gating, and visible action traces. That gives Airo the same user experience as Google AI Edge Gallery while keeping mobile privacy and platform permissions under app control.
