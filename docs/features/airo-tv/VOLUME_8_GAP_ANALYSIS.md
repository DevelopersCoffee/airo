# Airo TV Volume 8 Gap Analysis

**Volume:** Modular Product Profiles, Legacy Editions, and Capability-Based
Feature Delivery  
**Date:** 2026-07-13  
**Status:** Draft gap analysis  
**Input:** `/Users/udaychauhan/.codex/attachments/bd12346f-2147-469c-9a63-c1d809ce8801/pasted-text.txt`  
**Baseline inspected:** Android variant build configuration, TV pubspec,
platform feature configuration, feature flags, existing Airo TV plan,
requirements review, and prior gap analyses.

## Executive Summary

Volume 8 turns the legacy-device strategy into a product-composition strategy:
legacy support should not be the full app with scattered conditionals. It
should be a deliberately composed set of Airo editions built from shared core
contracts and profile-specific feature modules.

The current repository has partial foundations:

- Android builds support an `APP_VARIANT` value with a TV variant and lean
  native-library exclusions.
- `app/pubspec_tv.yaml` demonstrates TV-specific dependency stubbing to reduce
  binary size.
- `PlatformFeatures` maps broad app platforms to enabled feature groups.
- Existing plans already name Full TV, Standard TV, Lite Receiver, Embedded
  Receiver, and Experimental Legacy profiles.

Those foundations are not yet a Volume 8 product platform. There is no
first-class `ProductProfile` contract, profile manifest, module dependency
graph, product-composition validator, profile-specific navigation contract,
capability publication schema, delegation framework, remote view model,
release-channel matrix, or cross-profile compatibility suite.

## Requirement Intent

Volume 8 requires Airo TV to ship multiple product experiences from one shared
platform:

| Product profile | Role |
| --- | --- |
| Full TV | Rich modern TV app with local indexing, full EPG, profiles, recommendations, diagnostics, cloud continuity, and optional advanced features. |
| Standard TV | Mid-range TV experience with playback, limited EPG, favorites, search, profiles, phone remote, cloud continuity, and reduced visuals. |
| Lite Receiver | Android 8/9 and low-memory playback-first profile with pairing, direct playback, phone remote, favorites, recent, compact EPG, basic navigation, failover, sync, and minimal diagnostics. |
| Embedded Receiver | Thin receiver for operator/vendor/hospitality devices with activation, registration, playback receiver, commands, now-playing, error recovery, and updates. |
| Experimental Legacy | Clearly labeled community/direct builds with baseline playback, pairing, remote commands, limited compatibility, and no full support guarantee. |

The core rule is: compile-time composition controls what the application
contains; runtime capability control determines what the current device can
safely use.

## Current Repo Fit

| Current asset | Fit | Gap |
| --- | --- | --- |
| `APP_VARIANT` in Gradle | Partial build-time variant hook for full/iptv/streaming/tv | Not aligned to Full TV, Standard TV, Lite Receiver, Embedded Receiver, Experimental Legacy profiles |
| `isLeanVariant` native exclusions | Removes some heavy local AI native libraries from non-full variants | No declared module lifecycle, dependency graph, or profile manifest proving all heavy modules are absent |
| `pubspec_tv.yaml` | Demonstrates a lighter TV dependency set with stubs | Separate/manual mechanism; not a first-class product profile build system |
| `PlatformFeatures` | Basic platform-to-feature map for mobile full, mobile streaming, Android TV, iPad | Too broad for Volume 8; no resource budgets, dependencies, permission rules, release channel, or capability publication |
| `feature_flags.dart` | Compile-time performance overlay flag exists | No feature flag model tied to product profiles or absent-module protection |
| Existing package layout | Modular packages exist for core, IPTV, platform, history, favorites, AI | No enforced dependency direction or composition tests for Airo TV profiles |
| Existing Airo TV plan | Names product profiles and capability contracts | Needs concrete profile manifests, delegation, remote views, module lifecycle, and release-channel gates |

## Major Gaps

### 1. Product Profiles Are Named but Not Modeled

**Requirement:** Full TV, Standard TV, Lite Receiver, Embedded Receiver, and
Experimental Legacy should be first-class product profiles.

**Current state:** The plan names these profiles, but the code has broad
platform variants instead of Airo TV product profiles.

**Gap:** Define `ProductProfile`, `ProductProfileManifest`,
`ProfileCapabilitySet`, profile guarantees, exclusions, navigation, permissions,
resource budgets, release channel, and support level.

### 2. Shared Core Boundary Is Not Enforced

**Requirement:** Identity, auth, trusted devices, sessions, playback state,
media IDs, source refs, command protocol, security, errors, redaction,
capabilities, compatibility, and local config should be lightweight shared core.

**Current state:** Core packages exist, but there is no Airo TV shared-core
boundary proving optional product features are not imported by core modules.

**Gap:** Add dependency-direction rules and CI checks. Core must not import full
product apps or optional heavy features.

### 3. Optional Feature Modules Lack Manifests

**Requirement:** Optional modules such as full EPG, compact EPG, search, AI,
recording, downloads, multiview, diagnostics, cloud continuity, phone remote,
and voice input should declare dependencies and supported profiles.

**Current state:** Some packages exist; module metadata does not.

**Gap:** Add module manifests with supported profiles, required capabilities,
initialization cost, memory/storage budget, permissions, background jobs,
shutdown behavior, feature flags, and fallback behavior.

### 4. Compile-Time and Runtime Controls Are Not Separated Enough

**Requirement:** Compile-time exclusion controls what is included; runtime
capability controls what is safely used.

**Current state:** `APP_VARIANT`, `APP_PLATFORM`, stubs, and flags exist but are
not governed by one composition model.

**Gap:** Add rules so runtime flags cannot expose modules absent from the build.
Features with heavy native libraries, unsupported APIs, broad permissions, or
security risk should be compile-time excluded from constrained profiles.

### 5. Capability Contract Needs Product-Profile Semantics

**Requirement:** Every edition publishes capabilities: playback, local/remote
search, EPG window, AI, multiview, recording, cloud continuity, max resolution,
decoder count, and profile.

**Current state:** Capability ideas exist in planning, but no concrete Airo TV
profile capability schema exists.

**Gap:** Extend connected-device capability advertisements with
`productProfile`, compiled features, runtime capabilities, profile guarantees,
protocol version, and unsupported-reason codes.

### 6. Feature Dependency Graph Is Missing

**Requirement:** Invalid combinations should be blocked, such as multiview
without decoder detection, full EPG without storage support, AI inference
without model lifecycle, and recording without storage checks.

**Current state:** No graph validates product composition.

**Gap:** Add a build/profile dependency graph and tests that reject invalid
feature bundles.

### 7. Shared Interfaces Need Profile-Specific Implementations

**Requirement:** EPG, search, and AI should expose shared interfaces with full,
compact, remote, no-op, delegated, cloud, and fallback implementations.

**Current state:** Some feature packages are modular, but there is no shared
Airo TV provider interface across profile implementations.

**Gap:** Define interfaces such as `EpgRepository`, `SearchProvider`,
`AiProvider`, `DiagnosticsProvider`, and `MediaSourceResolver`, with profile
bindings.

### 8. Delegation Framework Is Missing

**Requirement:** Constrained devices should request search, parsing, EPG,
metadata, AI intent parsing, subtitles, stream health, artwork resizing, source
resolution, credential-assisted playback, and transcoding from trusted nodes.

**Current state:** Prior volumes define connected nodes and cloud/local
orchestration, but no task delegation framework exists.

**Gap:** Define delegated tasks with IDs, timeouts, versioned results,
encrypted payloads, capability confirmation, cancellation, duplicate
suppression, fallback, and user-visible unavailable states.

### 9. Remote View Models Are Missing

**Requirement:** Lite and embedded devices should consume compact remote views:
top results, current/next EPG, favorites, compact cards, and pre-ranked backup
streams.

**Current state:** No remote view schema exists.

**Gap:** Add `RemoteView`, `RemoteViewItem`, expiry, cacheability, redaction,
and profile-specific rendering rules.

### 10. Navigation and UI Component Tiers Are Not Profile-Driven

**Requirement:** Full, Lite, and Embedded profiles should expose different
navigation sections and component tiers.

**Current state:** TV UI exists, but no product-profile navigation manifest
prevents unavailable sections from appearing.

**Gap:** Add per-profile navigation manifests and design-system component tiers:
rich, standard, lightweight.

### 11. Data Ownership and Migration Are Underdefined

**Requirement:** Full TV, Lite TV, mobile/desktop, and home node need ownership
rules for playlist index, EPG, favorites, progress, AI embeddings, stream
health, artwork, thumbnails, and credentials.

**Current state:** Data ownership is discussed across prior volumes, but no
profile matrix is enforceable.

**Gap:** Add profile-scoped storage rules, sync ownership, Lite-to-Full
upgrade, Full-to-Lite downgrade, and cloud-state preservation for unsupported
features.

### 12. Release Channels and Store Strategy Need Decisions

**Requirement:** Airo may ship Full TV stable, Lite TV stable, Receiver stable,
Legacy experimental, vendor-specific, and internal certification channels.

**Current state:** Android variants exist, but no release-channel policy or
store-listing strategy is defined.

**Gap:** Decide single adaptive app vs separate Full/Lite apps vs device-targeted
delivery. Define versioning, rollout, crash thresholds, update cadence, feature
flags, and eligibility per channel.

### 13. Product Composition Tests Are Missing

**Requirement:** Every build profile must verify included modules, absent
navigation, permissions, native libraries, feature declarations, capability
announcements, protocol compatibility, and cross-profile workflows.

**Current state:** Some TV tests exist, but not composition-level tests.

**Gap:** Add module tests, profile composition tests, and cross-profile tests:
mobile to Lite TV, mobile to receiver-only, Full TV to Lite TV handoff, old/new
protocol mismatch, cloud outage, companion unavailable, unsupported transfer,
and delegation failure.

## Plan Additions Required

| Addition | Priority | Why |
| --- | --- | --- |
| Product profile manifest | P0 | Converts profile names into enforceable build/runtime contracts |
| Module manifest schema | P0 | Required for dependency graph, budgets, permissions, and fallbacks |
| Composition validator | P0 | Prevents invalid builds and runtime exposure of absent modules |
| Capability advertisement schema | P0 | Controllers and routers need profile-aware capability data |
| Delegation task framework | P0 | Lite/embedded devices depend on trusted nodes for expensive work |
| Remote view model | P1 | Prevents constrained devices from consuming full datasets |
| Profile navigation manifests | P1 | Avoids empty/unavailable sections in Lite and Embedded Receiver |
| UI component tiers | P1 | Keeps brand consistency while reducing rendering cost |
| Profile data ownership matrix | P1 | Required for sync, migration, credentials, and progress |
| Release channel and store strategy | P1 | Required before separate Lite/Receiver distribution |
| Cross-profile compatibility tests | P1 | Required to keep one ecosystem across different editions |

## Acceptance Coverage Gaps

Volume 8 acceptance criteria are not yet testable. The first contract tests
should prove:

- Lite Receiver build excludes AI, recording, multiview, downloads, and full
  EPG dependencies.
- Lite and Full share the same session, playback, command, and media ID
  contracts.
- Unsupported features are absent from navigation and cannot be enabled by
  runtime flags.
- Device capability announcements match compiled modules and runtime safety.
- A controller can delegate search and EPG to a trusted node.
- Lite remains useful when the companion is unavailable.
- Receiver-only mode can play authorized media without a full local catalog.
- Heavy native libraries and unused permissions are absent from constrained
  builds.
- Favorites and progress sync across Full, Lite, mobile, and receiver profiles.
- Unsupported handoffs are rejected before current playback stops.
- Protocol compatibility covers old receiver/new controller and old
  controller/new receiver combinations.

## Product Packaging Impact

Volume 8 strengthens the recommendation that Airo TV should ship at least three
clearly defined TV products over time:

- **Airo TV:** Full/standard modern TV experience.
- **Airo TV Lite:** legacy and low-memory TV receiver-focused experience.
- **Airo Receiver:** embedded/operator/thin receiver experience.

The immediate v2.0.0.1 scope should remain contracts and validation. Separate
store listings or targeted delivery should not be committed until dependency
size, store capability, support, release management, and user-confusion risks
are reviewed.

## Open Questions

- Should Airo TV Lite be a separate app listing, device-targeted app bundle
  variant, or one adaptive app mode?
- What exact module manifest format should be used: Dart declarations, YAML, or
  generated build metadata?
- Which features must be compile-time excluded for Lite and Receiver profiles?
- Which permissions are allowed per profile?
- What is the first delegation host: phone, desktop, home node, or cloud?
- How should separate product profiles version independently while preserving
  protocol compatibility?
- What are the minimum resource budgets for Full TV, Standard TV, Lite
  Receiver, and Embedded Receiver?
- What migration behavior is required when a user moves from Lite to Full or
  Full to Lite?
- Which release channel owns experimental legacy devices?

## Recommendation

Fold Volume 8 into v2.0.0.1 as the product-composition contract. The next
implementation issue should not be “hide features on old TVs”; it should be
“define product profile manifests and validate composition.” This keeps legacy
support maintainable, makes Lite Receiver a deliberate product, and prevents
runtime conditionals from becoming the architecture.
