# Airo TV Volume 7 Gap Analysis

**Volume:** Legacy Android TV Support, Constrained Hardware Optimization, and
Maximum Device Reach  
**Date:** 2026-07-13  
**Status:** Draft gap analysis  
**Input:** `/Users/udaychauhan/.codex/attachments/eabe98db-608b-47ca-8e2b-60eb1f5fff0d/pasted-text.txt`  
**Duplicate source verified:** `/Users/udaychauhan/.codex/attachments/1fab2782-4453-4300-b20c-d7482c6fa449/pasted-text.txt`  
**Baseline inspected:** Android build configuration, TV pubspec, TV
form-factor/input/focus helpers, Cast proxy, TV integration tests, prior Airo TV
planning docs, and Volume 5 performance analysis.

## Executive Summary

Volume 7 defines how Airo TV should reach older Android TV, Fire TV, AOSP TV
boxes, operator boxes, and low-cost HDMI devices without lowering the bar for
security or playback quality. The product principle is clear: constrained TVs
should be excellent playback receivers, not overloaded media-processing
computers.

The repository already has important starting points:

- Android `minSdk = 26`, matching the proposed Android 8.0 baseline.
- Android `targetSdk = 36`, allowing target-SDK updates without dropping older
  runtime support by default.
- A TV app variant and `pubspec_tv.yaml` that stubs or removes several heavy
  dependencies for TV builds.
- Android TV / Fire TV form-factor detection, D-pad key mapping, focus helpers,
  safe-zone utilities, TV shell, and IPTV TV widgets.
- TV-oriented tests for focus, input, Fire TV keys, and several documented
  manual device checks.
- AI memory-budget logic that can inform but not replace TV-wide device
  profiling.

The gaps are mostly architectural and validation-related. There is no Airo TV
runtime device profile, Legacy Receiver Mode contract, certification framework,
hardware/media compatibility matrix, dependency-governance inventory, degraded
feature policy, constrained-TV resource scheduler, real-device benchmark suite,
or restricted receiver trust implementation.

## Requirement Intent

Volume 7 requires Airo TV to support the widest practical set of Android-based
TV devices through capability-based certification, not optimistic OS-version
claims.

| Requirement area | Intent |
| --- | --- |
| Android baseline | Start at Android 8.0 / API 26; evaluate lower versions only after certification. |
| Support tiers | Fully Supported, Legacy Optimized, Experimental, Unsupported. |
| Device profiling | Classify by hardware, codecs, memory, storage, network, remote input, thermals, and security posture. |
| Legacy Receiver Mode | Lightweight home, direct playback, D-pad navigation, compact EPG, phone-assisted search, and stream recovery. |
| Graceful degradation | Hide or replace features when capability is insufficient instead of showing generic unsupported errors. |
| Security | Old devices may use restricted receiver trust and short-lived playback tickets rather than full credentials. |
| Certification | Real-device tests must prove install, launch, navigation, playback, recovery, memory, storage, and update path. |

## Current Repo Fit

| Current asset | Fit | Gap |
| --- | --- | --- |
| `app/android/app/build.gradle.kts` | Sets `minSdk = 26` and `targetSdk = 36` | No automated guard proving dependencies do not silently raise effective support |
| `app/pubspec_tv.yaml` | Reduces TV build weight through stubs and dependency overrides | Build process appears separate/manual; no dependency governance report with API, size, memory, TV issues |
| `DeviceFormFactorDetector` | Detects TV form factor and Fire TV/Android TV platform shape | Does not collect RAM, storage, CPU, GPU, codec, network, thermal, security patch, or device-tier profile |
| `TvInputHandler` | Maps D-pad, media keys, channel keys, Fire TV voice/home/search keys | No certification matrix across actual remotes/operator boxes |
| `TvFocusManager` | Focus memory and focus constants exist | Focus animation is 200ms while Volume 7 targets visible focus response under 100ms; no stress tests for rapid navigation/artwork loading |
| IPTV TV widgets and TV shell | Provides a TV-oriented experience | Not a defined Legacy Receiver Mode with strict feature caps, compact data budgets, and automatic degradation |
| `CastHttpProxy` | Proxies and rewrites remote HLS resources and forwards Range headers upstream | It is not a secure temporary phone file server with local file serving, auth tokens, expiry, battery/thermal gating, and verified `206 Partial Content` handling |
| TV integration tests | Some focus/input requirements are covered; many device checks are documented | Many tests are placeholders requiring physical device validation; no certification harness or long-duration stress suite |
| `core_ai` memory budget | Useful memory-check precedent | AI-specific; not a TV-wide resource budget for player, UI, EPG, artwork, database, protocol, and native buffers |

## Major Gaps

### 1. Runtime Device Profile Is Missing

**Requirement:** On first launch, Airo TV should classify Android API, platform,
model class, CPU, RAM, storage, GPU, hardware codecs, max resolution, audio
codecs, decoder count, network class, remote capability, thermal APIs, vendor
restrictions, and device tier.

**Current state:** The app can detect TV vs non-TV and has AI memory helpers,
but there is no Airo TV device profile model.

**Gap:** Define `AiroTvDeviceProfile`, `DeviceTier`,
`DeviceConstraintState`, and dynamic reclassification rules for memory, storage,
thermal, network, and decoder failures.

### 2. Legacy Receiver Mode Is Not Defined as a Contract

**Requirement:** Constrained devices should default to a lightweight receiver
experience: continue watching, live now, favorites, recent, paired-device
status, search from phone, current program, settings, and diagnostics.

**Current state:** TV screens exist, but there is no strict Legacy Receiver Mode
contract that disables expensive shelves, animations, full indexing, previews,
heavy artwork, AI inference, and background processing.

**Gap:** Add a framework-owned mode that drives navigation, available features,
data budgets, artwork density, animation policy, and delegated search/EPG/AI
behavior.

### 3. Capability-Based Support Tiers Are Not Implemented

**Requirement:** Support is defined by capability, not OS alone: Fully
Supported, Legacy Optimized, Experimental, Unsupported.

**Current state:** The build baseline is API 26, but no runtime support-tier
classification or user-visible compatibility status exists.

**Gap:** Add certification levels and a device support decision model. Do not
advertise a device class until the real-device certification suite passes.

### 4. Dependency Governance Is Missing

**Requirement:** Every dependency must declare minimum Android API, native
architecture, size, memory impact, background behavior, shrinker requirements,
hardware-decoder assumptions, maintenance status, and known TV issues.

**Current state:** `pubspec_tv.yaml` reduces heavy TV dependencies, and the
Gradle file excludes some native LLM libraries for lean variants.

**Gap:** Add a dependency audit artifact and CI check. Any dependency that
raises the effective minimum API must be replaced, forked, isolated behind an
optional module, or explicitly justified.

### 5. Native Media Compatibility Is Not Certified

**Requirement:** Certified legacy devices must prove native hardware-accelerated
decoding for H.264/AAC/HLS/MPEG-TS/MP4/subtitles, with fallbacks across decoder
configuration, backend, backup stream, reduced resolution, and compatibility
error.

**Current state:** Android playback currently relies on `video_player`
wrapping ExoPlayer; Volume 5 found no native media-engine abstraction or
hardware compatibility matrix.

**Gap:** Add media capability probing, decoder inventory, backend fallback
rules, and real-device playback evidence. Do not claim 4K, HDR, HEVC, AV1, or
multi-view without device-specific proof.

### 6. Temporary Phone Media Streaming Is Not Volume 7 Ready

**Requirement:** Phone media serving is only for phone-local files and must
support `GET`, `HEAD`, Range parsing, `206 Partial Content`, accurate
`Content-Length`, `Content-Range`, MIME detection, cancellation, temporary
tokens, expiry, and battery/thermal protections.

**Current state:** `CastHttpProxy` is a compatibility proxy for remote HLS
resources. It forwards upstream Range headers but does not implement a secure
local file server contract.

**Gap:** Keep the current proxy compatibility-only. Add a separate secure
temporary media-server contract before local phone file streaming is shipped.

### 7. UI, Focus, and Widget Performance Budgets Are Not Enforced

**Requirement:** Legacy mode must avoid blur, heavy clipping, nested
animations, shader effects, parallax, auto-playing previews, excessive image
fades, oversized posters, full-screen rebuilds, and unbounded focus animation
queues.

**Current state:** TV focus/input helpers exist. Focus constants currently set a
200ms animation duration, while Volume 7 targets visible focus response under
100ms.

**Gap:** Add Legacy UI component tiers, focus-latency tests, rapid D-pad stress
tests, artwork-loading focus stability tests, selector/rebuild rules, and
long-list virtualization checks.

### 8. Memory, Storage, and Resource Scheduling Are Not Centralized

**Requirement:** Define budgets for Flutter heap, native heap, media decoder,
video buffer, artwork cache, DB cache, EPG data, network buffers, and protocol
state. Playback must have highest priority under pressure.

**Current state:** AI memory checks exist, but no cross-product resource
scheduler or TV budget model exists.

**Gap:** Add tier-specific memory/storage budgets, low-storage mode, memory
pressure response, background-work deferral during playback, and bounded
artwork/EPG/database caches.

### 9. Network Reliability and Diagnostics Need Legacy-Specific Contracts

**Requirement:** Weak Wi-Fi handling should detect packet loss, bounded retry,
backup streams, bitrate reduction, provider-vs-local failure classification,
and diagnostics for bitrate, buffer, DNS, latency, decoder errors, and
reconnect count.

**Current state:** Playback failure handling and metrics are partial; no legacy
network diagnostic model exists.

**Gap:** Add network-health classification, recovery phases, no-loop retry
rules, and privacy-safe diagnostics exposed to users/support.

### 10. Distributed EPG, Search, and AI Are Not Productized for Legacy TVs

**Requirement:** Large EPG/search/AI work should be offloaded to trusted phone,
desktop, home node, or cloud. TVs receive compact EPG windows and result sets.

**Current state:** Prior plans define distributed EPG/search/AI contracts, but
implementation is missing.

**Gap:** Legacy Receiver Mode must depend on delegated EPG/search/AI contracts
from Volumes 2, 3, 5, and 6 before claiming large library support on old TVs.

### 11. Restricted Receiver Trust Mode Is Missing

**Requirement:** Legacy devices may be restricted receivers: they receive
short-lived playback tickets, play approved content, report state, and accept
basic commands, but cannot manage billing, export playlists, add trusted
devices, change security settings, or access unrestricted profiles.

**Current state:** Volume 6 added the playback-ticket requirement, but no
restricted trust implementation or policy artifact exists.

**Gap:** Add restricted trust mode to device identity, profile permissions,
pairing, cloud orchestration, and settings.

### 12. Store and Distribution Strategy Is Not Complete

**Requirement:** Google Play, Amazon Appstore, and direct APK distribution each
need specific quality, remote input, billing, signing, update, rollback, and
permission rules.

**Current state:** There is a TV variant and release signing logic, but no
store/distribution matrix for legacy devices.

**Gap:** Add release-owner decisions for Play TV, Amazon Appstore, direct APK,
operator boxes, and experimental builds.

### 13. Certification Program and Stress Tests Are Missing

**Requirement:** Certification must cover install, cold start, remote
navigation, focus stability, HLS/VOD playback, hardware decoding, subtitles,
audio tracks, pairing, remote control, cloud recovery, failover, memory
pressure, low storage, resume, sleep/wake, reconnect, long playback, thermals,
and crash rate.

**Current state:** TV tests include several unit-level checks and manual
requirements, but there is no certification harness or device inventory.

**Gap:** Add device classes, physical-device inventory, automation scripts,
manual evidence templates, benchmark thresholds, and release gates.

## Plan Additions Required

| Addition | Priority | Why |
| --- | --- | --- |
| Runtime device profile model | P0 | Capability-over-version is the core Volume 7 policy |
| Legacy Receiver Mode contract | P0 | Prevents old TVs from loading rich/full experiences |
| Dependency governance audit | P0 | Protects API 26 support from accidental dependency inflation |
| Certification matrix and evidence format | P0 | Device support claims require real-device proof |
| Media capability and decoder probe contract | P0 | Required before playback/resolution/codec claims |
| Legacy UI/focus performance budget | P1 | Required for D-pad stability and perceived quality |
| Memory/storage/resource budget model | P1 | Required to preserve playback under pressure |
| Secure phone-local media server contract | P1 | Current Cast proxy is not sufficient for local file streaming |
| Restricted receiver trust mode | P1 | Required for insecure or old devices |
| Store/distribution matrix | P1 | Play, Amazon, direct APK, and operator boxes have different constraints |

## Acceptance Coverage Gaps

The first test plan should prove:

- API 26 build installs and launches on certified Android 8/9 hardware.
- D-pad navigation works without touch input on Android TV and Fire TV remotes.
- Focus movement remains stable while artwork loads and rapid D-pad input is
  sent.
- Baseline H.264/AAC/HLS/MPEG-TS/MP4 plays through native rendering.
- Large catalogs are not loaded into TV memory.
- A paired phone can search and start playback, and TV playback continues after
  the phone disconnects.
- Compact EPG works without local full XMLTV processing.
- Memory pressure reduces caches while preserving active playback.
- Low storage does not corrupt credentials, favorites, or watch progress.
- Unsupported codecs produce alternate-source selection or a clear
  compatibility message.
- Direct internet-hosted media does not route through the phone.
- Phone-hosted local files return correct `206 Partial Content` responses.
- Legacy devices can be placed in restricted receiver trust mode.
- Cloud outage does not disable core local playback.

## Product Packaging Impact

Volume 7 should be handled as a compatibility strategy, not a promise to support
every old device. Recommended packaging:

- **Certified:** advertised support, standard support expectations, all core
  requirements pass.
- **Compatible:** core playback works; selected premium features unavailable.
- **Experimental:** installation/playback may work; no support guarantee.
- **Unsupported:** critical security, playback, or stability requirements fail.

Lowering below API 26 should remain explicitly out of scope until the
dependency, security, media, and real-device certification gates pass.

## Open Questions

- What exact devices make up the Android 8/9 certification inventory?
- What RAM/storage thresholds define Fully Supported vs Legacy Optimized vs
  Experimental?
- Which media backend should be the certification baseline: `video_player`
  ExoPlayer, Media3, LibVLC, MPV, or a hybrid?
- What codec and stream fixtures define baseline certification?
- Which dependencies currently set the effective minimum API above 26, if any?
- Is `pubspec_tv.yaml` the long-term TV build mechanism, or should product
  profiles become first-class build targets?
- What is the minimum acceptable secure storage posture for old or rooted TV
  boxes?
- Which distribution channels are approved for experimental legacy builds?
- What physical-device evidence is required before marketing claims support?

## Recommendation

Keep API 26 as the initial production baseline and add Volume 7 as a
certification-first workstream. The next useful artifact is a platform
compatibility and certification specification with exact device classes, RAM
thresholds, codec fixtures, store channels, feature flags, and automated
benchmark gates. Do not advertise lower Android support or premium legacy
features until that evidence exists.
