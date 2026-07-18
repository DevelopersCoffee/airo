---
name: Agent Task
about: Deferred community request
title: '[DEFERRED] CV-014: Decoupled Playback Engine Rewrite'
labels: 'agent/media, agent/framework, P3, enhancement, community-voice, v2-deferred'
assignees: ''
---

## V2 Milestone Decision

**Decision:** Defer from current v2.

**Reason:** A cross-platform Rust FFI playback controller with GPU texture sharing is high-risk native architecture work. It should not be mixed into v2 Play Store/performance hardening. Current v2 should improve diagnostics around the existing playback engine and preserve clean adapter seams.

## What To Keep From The Community Request

- Playback engine contracts should remain mockable and platform-aware.
- Codec/player failures should be observable through CV-001 diagnostics.
- Future engine selection should be based on protocol, codec, platform, and user preference.
- Existing `platform_player` models are the right place to keep adapter concepts.

## What Not To Build In Current V2

- No Rust FFI playback controller.
- No GPU texture registry pipeline.
- No Media3/AVFoundation/mpv/libVLC adapter implementation.
- No dynamic engine plugin switching.
- No native build matrix expansion for this milestone.

## Future Feature Packet Gate

**Problem:** Airo may eventually need a unified playback abstraction across Android, Apple, desktop, and web.
**User / actor:** User playing streams with codecs/protocols unsupported by the default engine.
**Framework or application layer:** Framework.
**Owning agent:** Media Agent.
**Reviewing agents:** Framework Agent, QA Automation Agent, Release and DevEx Agent, Security and Privacy Agent.
**Impacted modules/files:** `packages/platform_player`, native platform code, possibly `rust/airo_core`.
**Base branch/worktree:** Must be reconfirmed from latest `origin/main` or a dedicated native architecture branch when reopened.
**Open questions:** Engine choices, native dependency licensing, build matrix, texture ownership, memory safety, fallback policy.
**Decision:** Blocked until native architecture spike is approved.

## Future Cross-Agent Contract Required

**Provider agent:** Media Agent.
**Consumer agent:** Feature IPTV and other media surfaces.
**Interface/API:** Playback controller, engine adapter, texture renderer, track selector.
**Input shape:** Media URL, headers, protocol metadata, track preferences, platform capability profile.
**Output shape:** Playback state, texture id/frame sink, diagnostics, track list.
**State changes:** Playback session state only.
**Errors:** Engine unavailable, codec unsupported, texture allocation failure, native crash, memory leak.
**Permissions:** No new permission by default.
**Privacy/redaction:** Playback diagnostics redact credentialed URLs.
**Persistence:** User engine preference only if approved.
**Versioning/migration:** Native API versioning required.
**Tests required:** Fake engine lifecycle, native smoke tests, leak tests, platform build tests.

## Reopen Criteria

- CV-001 diagnostics are implemented.
- Native dependency/legal review is complete.
- A spike proves one platform path before cross-platform rollout.
