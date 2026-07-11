# Daily Project Health Monitor: Core AI Device Capability Log Noise

## Feature Packet

**Primary owner agent:** Framework Agent
**Review agents:** QA Automation Agent
**Layer:** Framework
**Sprint:** Daily project health monitor
**Parent roadmap:** Host-only validation hardening

### Critical Agent Gate

**Problem:** `packages/core_ai` host-side tests pass, but repeated `DeviceCapabilityService` platform-channel probes emit `ServicesBinding` initialization errors into test output. The noise obscures real failures and weakens CI signal quality.
**User / actor:** Release and DevEx Agent, QA Automation Agent, maintainers reviewing host-only test logs.
**Framework or application layer:** Framework / Core AI runtime boundary.
**Owning agent:** Framework Agent.
**Reviewing agents:** QA Automation Agent.
**Impacted modules/files:** `packages/core_ai/lib/src/device/device_capability_service.dart`, `packages/core_ai/test/device/device_capability_service_test.dart`
**Base branch/worktree:** confirmed from latest `origin/main`: yes
**Open questions:** None for this maintenance slice; behavior stays unchanged except for suppressing a known non-actionable log path.
**Decision:** Ready

### Deterministic Use Cases

1. When a host-side test touches `DeviceCapabilityService` before a Flutter services binding exists, the call returns unknown device capability information without printing the known binding-initialization error.
2. When a real platform-channel failure occurs, `DeviceCapabilityService` still logs the failure for diagnosis and returns unknown capability information.
3. Core AI host-only tests remain green after the log-noise hardening.

### Automation Flow

1. Run `cd packages/core_ai && flutter test --reporter=compact`.
2. Exercise `DeviceCapabilityService` through existing model/runtime tests and the dedicated device-capability regression test.
3. Confirm binding-initialization noise is suppressed while unexpected failures still surface in logs.

### Implementation Boundaries

- Framework files: `packages/core_ai/lib/src/device/device_capability_service.dart`
- Application files: none
- Tests: `packages/core_ai/test/device/device_capability_service_test.dart`
- Docs: `docs/agents/automation/daily-project-health-monitor/2026-07-04-core-ai-device-capability-log-noise.md`
- Verification environment: host-only Flutter test run on macOS
