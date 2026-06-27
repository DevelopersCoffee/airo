---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] P0 guardrail for Android Emulator QEMU crashes in agent verification'
labels: 'agent/devex, agent/qa-testing, priority/P0, type/bug, platform-android'
assignees: ''
---

## Agent

**Agent:** agent/devex, agent/qa-testing

## Task Details

**Estimate (hours):** 3

**Priority:** P0

## Description

Agent-run Android journey verification can boot the local Pixel 9 Android
Emulator by default. On macOS 26.x hosts, the Android Emulator process can crash
inside `qemu-system-aarch64` with `EXC_BAD_ACCESS / KERN_INVALID_ADDRESS`.
This is a host infrastructure failure, not an Airo app crash, but repeated
agent retries waste time and can lose test state.

The default agent workflow must avoid Android Emulator/QEMU unless a maintainer
or issue explicitly accepts that risk.

## Critical Agent Gate

**Problem:** Android Emulator/QEMU can crash during agent verification and cause
agents to repeatedly chase a non-app failure.

**User / actor:** LLM implementation agents, QA agents, and maintainers running
local journey checks.

**Framework or application layer:** Framework/tooling and process policy.

**Owning agent:** agent/devex

**Reviewing agents:** agent/qa-testing, agent/release

**Impacted modules/files:**
- `scripts/run_agent_skills_journey.sh`
- `Makefile`
- `docs/agents/AGENT_POLICY.md`
- `docs/agents/RULES.md`
- `docs/agents/SDLC.md`
- `.github/ISSUE_TEMPLATE/agent_task.md`
- `.github/PULL_REQUEST_TEMPLATE.md`

**Open questions:** None. Android Emulator can still be used with explicit
`AIRO_ALLOW_ANDROID_EMULATOR=true` opt-in.

**Decision:** Ready

## Cross-Agent Contract

**Provider agent:** agent/devex

**Consumer agent:** agent/qa-testing and implementation agents

**Interface/API:** Environment-gated commands:
- `AIRO_ALLOW_ANDROID_EMULATOR=true`
- `AIRO_JOURNEY_ANDROID_DEVICE=<adb-serial>`
- `AIRO_JOURNEY_PLATFORM=ios|android`

**Input shape:** Shell environment variables.

**Output shape:** Commands fail fast with exit code `78` and a clear message
when Android Emulator use is not explicitly allowed.

**State changes:** No application state changes.

**Errors:** Emulator path is blocked by default; physical-device and iOS
simulator paths remain available.

**Permissions:** No new permissions.

**Privacy/redaction:** No user data is collected.

**Persistence:** No persistent app data changes.

**Versioning/migration:** Backward compatible for host checks and physical
devices; emulator users must opt in.

**Tests required:** Shell syntax checks and command dry-runs for the blocked
path.

## Deterministic Use Cases

### UC-001: Agent Runs Default Journey Check

**Actor:** LLM implementation agent

**Preconditions:** No explicit Android Emulator opt-in is set.

**Trigger:** Agent runs `make test-agent-skills-journey`.

**Happy path:** The journey uses the default iOS simulator path and does not
boot Android Emulator/QEMU.

**Alternate paths:** Agent can set `AIRO_JOURNEY_PLATFORM=android` and provide
`AIRO_JOURNEY_ANDROID_DEVICE=<adb-serial>` to run on a physical Android device.

**Failure paths:** If Android is requested with no physical device and no opt-in,
the script exits `78` with remediation instructions.

**Data created/updated/deleted:** Test artifacts only when a journey actually
runs.

**Privacy expectations:** No app data leaves the machine.

### UC-002: Maintainer Explicitly Accepts Emulator Risk

**Actor:** Maintainer or QA agent

**Preconditions:** Android Emulator verification is required and the issue
accepts emulator risk.

**Trigger:** Maintainer runs `AIRO_ALLOW_ANDROID_EMULATOR=true make
test-agent-skills-journey-android-emulator`.

**Happy path:** The script boots the Pixel 9 AVD and runs the Android journey.

**Failure paths:** If QEMU crashes, agents stop the emulator path, attach the
crash report, and continue with host or physical-device verification.

**Data created/updated/deleted:** Emulator state and test artifacts only.

**Privacy expectations:** No production user data is used.

## Automation Flow

### AUTO-001: Block Android Emulator by Default

**Given:** `AIRO_JOURNEY_PLATFORM=android` and no physical Android device is
selected.

**When:** `scripts/run_agent_skills_journey.sh` is executed without
`AIRO_ALLOW_ANDROID_EMULATOR=true`.

**Then:** The script exits `78`, prints a message explaining that Android
Emulator/QEMU is disabled by default, and does not invoke `make boot-pixel9`.

**Fixtures:** Shell environment with no `AIRO_JOURNEY_ANDROID_DEVICE`.

**Mocks/stubs:** None.

**Assertions:** Exit code is `78`; output mentions physical Android and
`AIRO_ALLOW_ANDROID_EMULATOR=true`.

**Cleanup:** None.

## Acceptance Criteria

- [ ] Android Emulator boot is blocked by default for agent journey scripts.
- [ ] Physical Android devices remain supported through
      `AIRO_JOURNEY_ANDROID_DEVICE`.
- [ ] Explicit emulator opt-in remains available with
      `AIRO_ALLOW_ANDROID_EMULATOR=true`.
- [ ] Agent rules classify QEMU crashes as infrastructure failures and prohibit
      retry loops.
- [ ] Issue and PR templates require verification environment disclosure.

## CI Checklist

- [ ] Shell syntax check passes for `scripts/run_agent_skills_journey.sh`.
- [ ] Dry-run blocked path exits `78` without booting the emulator.
- [ ] Docs updated.

## Files to Modify

```text
scripts/run_agent_skills_journey.sh
Makefile
docs/agents/AGENT_POLICY.md
docs/agents/RULES.md
docs/agents/SDLC.md
.github/ISSUE_TEMPLATE/agent_task.md
.github/PULL_REQUEST_TEMPLATE.md
```

## Dependencies

None.

## Release Note Required?

No user-facing release note. This is an agent/devex guardrail.
