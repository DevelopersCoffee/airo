# Airo TV Volume 4 Gap Analysis

**Source:** `/Users/udaychauhan/.codex/attachments/a91522db-dca0-436d-9264-7516949d1ea8/pasted-text.txt`  
**Date:** 2026-07-13  
**Scope:** Media Routing Engine, playback delegation, route selection, local
mobile streaming, smart buffering, session ownership, and Edge Media Node.

## Executive Summary

Volume 4 corrects an important architectural risk: Airo TV should not treat the
phone as the default media server. The phone should orchestrate playback, while
the destination device, cloud origin, NAS, desktop, or future Edge Media Node
serves media bytes whenever possible. Phone-hosted streaming should happen only
when the media physically exists only on the phone.

The current repository has early ingredients: Cast discovery/session models,
an IPTV Cast adapter, an opt-in local HTTP proxy with range forwarding, IPTV
stream state, and a unified media content model with stream URLs. It does not
yet have a Media Routing Engine, media source location model, route optimizer,
device/media compatibility engine, playback ownership model, battery/thermal
rules, secure temporary mobile server, NAS/server adapters, or event-driven
remote playback health sync.

This means Volume 4 should be added to the plan as a foundation contract layer
that sits between Volume 2 media sources, Volume 3 connected devices, and the
existing player/cast code.

## Current Repository Fit

| Requirement area | Current evidence | Fit |
| --- | --- | --- |
| Cast control surface | `AiroCastController`, `AiroCastSessionSnapshot`, IPTV cast provider | Partial |
| Local HTTP proxy | `CastHttpProxy` starts a local `HttpServer`, proxies range requests, rewrites playlists | Partial |
| Direct URL playback | IPTV models and `AiroCastMediaRequest.url` support URL-based loading | Partial |
| Playback state | `StreamingState`, IPTV player service, Cast session snapshots | Partial |
| Unified media item | `UnifiedMediaContent` has title, image, stream URL, resume position | Minimal |
| Media routing engine | No route scoring, route plan, or route execution contract found | Missing |
| NAS/server direct playback | No SMB, NFS, DLNA, Plex, Jellyfin, or Emby dependencies found | Missing |
| Media capability detection | No shared codec/container/HDR/audio/subtitle inspector found | Missing |
| Compatibility engine | No device/media compatibility decision contract found | Missing |
| Battery and thermal routing | No battery or thermal dependency found in pubspecs | Missing |
| Secure temporary mobile server | Existing proxy is Cast compatibility-oriented, not an authenticated local media server | Missing |
| Playback ownership | Cast snapshots track device/media, but no owner model across phone/TV/desktop/cloud | Missing |

## Major Gaps

### 1. Media Routing Engine Is Missing

Volume 4 requires Airo to choose the optimal transport before playback starts:
direct cloud, NAS/server direct, desktop relay, local TV playback, or temporary
mobile server only as a last resort.

Current state:
- IPTV playback and Cast flows can load a URL.
- `IptvCastNotifier.castChannelToDevice` connects to a Cast device and loads a
  cast request directly.
- There is no intermediate route decision model between user intent and player
  execution.

Gap:
- No `MediaRoutePlan`, `MediaRouteCandidate`, `MediaRouteDecision`, or
  `MediaRoutingEngine`.
- No ranked strategy order: cloud, NAS, desktop, TV-local, then phone.
- No route scoring based on network, battery, CPU, storage, codec, DRM,
  internet availability, user preferences, or server health.
- No explainability for why a route was selected or rejected.

Planning impact:
- Add a P0 Media Routing Engine contract before building more cast, handoff, or
  mobile-server behavior.

### 2. Media Location Model Is Too Simple

Volume 4 distinguishes where media lives: cloud, IPTV, NAS, desktop, phone, USB
on TV, and future edge nodes.

Current state:
- `UnifiedMediaContent` primarily carries a single `streamUrl`.
- IPTV channel models carry stream URLs and quality variants.
- Volume 2 planning has media-source concepts, but the current app model does
  not represent source locality or route-specific access.

Gap:
- No canonical `MediaLocation` abstraction.
- No distinction between public URL, authenticated URL, LAN file path, phone
  local file, TV USB file, NAS share, media server item, or relay candidate.
- No credential-safe route token model.
- No support for multiple equivalent sources for the same media item.

Planning impact:
- Volume 2 canonical media models should feed Volume 4 route planning.

### 3. Device Capability Engine Is Not Routing-Ready

Volume 4 requires devices to publish storage, CPU, RAM, GPU, decoder support,
HDR, Dolby, network, battery, charging, and temperature.

Current state:
- `core_ai` has limited device capability checks for AI use cases.
- Volume 3 planning added connected-node capability advertisements.
- Existing Cast device models hold only id, name, optional model, host, port,
  and last-seen timestamp.

Gap:
- No playback-oriented capability schema.
- No decoder/HDR/audio-pass-through inventory.
- No battery, charging, or thermal telemetry for phones/tablets.
- No route eligibility rules based on device health.

Planning impact:
- Connected-node capabilities need a media-routing profile, not only generic
  device identity.

### 4. Media Capability Detection Is Missing

Volume 4 requires media inspection for codec, resolution, HDR, bitrate,
container, audio, subtitles, language, and duration.

Current state:
- IPTV stream models expose basic channel and quality information.
- The player service estimates bitrate from selected quality.
- No shared media analyzer was found.

Gap:
- No `MediaCapabilities` model.
- No manifest/file probing interface.
- No subtitle/audio track discovery before route selection.
- No compatibility result for direct play versus alternative source versus
  future transcode.

Planning impact:
- PlaybackEngine should not be the first component to discover incompatibility;
  the routing engine needs preflight capability detection.

### 5. Compatibility Engine Is Missing

Volume 4 requires preflight checks for codec, decoder, container, bandwidth,
subtitles, HDR, and Dolby before playback.

Current state:
- Playback errors are mostly discovered during load/play.
- Cast errors cover unsupported stream and media load failure.
- There is no route-level compatibility matrix.

Gap:
- No `CompatibilityCheck` or `RouteEligibility` model.
- No alternate-source selection when the first route is not playable.
- No future transcode placeholder contract.
- No user-facing fallback taxonomy for unsupported codec, expired URL,
  insufficient bandwidth, unavailable NAS, or battery constraint.

Planning impact:
- Route selection must run before handoff so source playback is not stopped for
  an unplayable destination.

### 6. Local Mobile Streaming Is Not Secure Enough For Volume 4

Volume 4 allows phone-hosted streaming only when the media exists only on the
phone. It requires HTTP Range, HEAD, resume, chunked transfer, ETag, keep-alive,
partial content, session tokens, LAN-only access, encryption or secure channel,
auto expiration, and shutdown.

Current state:
- `CastHttpProxy` starts a local HTTP server and forwards Range headers.
- It sets `Accept-Ranges` and forwards `Content-Range`.
- It is designed for Cast compatibility and origin playlist rewriting.
- It accepts a `url` query parameter and uses permissive CORS headers.

Gap:
- No authenticated temporary URL.
- No signed session token.
- No local-file serving path for phone-only media.
- No HEAD handling contract.
- No ETag, expiry, auto-shutdown, or trusted-device authorization.
- No LAN-only authorization enforcement beyond binding/listening behavior.
- No encryption layer.

Planning impact:
- Keep `CastHttpProxy` as a compatibility proxy. Do not promote it into the
  Volume 4 mobile media server without a new security contract.

### 7. Smart Buffer And Adaptive Streaming Control Are Incomplete

Volume 4 defines buffer levels and adaptive actions based on buffer, CPU,
battery, temperature, Wi-Fi, and packet loss.

Current state:
- `VideoPlayerStreamingService` tracks buffered-ahead and buffer health.
- It has metrics and live-edge monitoring.
- It explicitly avoids automatic retry after playback errors.

Gap:
- No buffer policy levels: critical, minimum, optimal, aggressive.
- No route-level adaptive decision to switch routes, reduce bitrate, pause
  buffering, increase cache, reconnect, or switch mirror.
- No battery/thermal/network packet-loss inputs.
- No backup route candidate pool.

Planning impact:
- Playback hardening should include route health and adaptive route actions,
  not only player retry behavior.

### 8. Playback Session Ownership Is Missing

Volume 4 says every session has one owner: phone, TV, desktop, tablet, or
cloud. Ownership determines pause, resume, seek, recording, analytics, and
health reporting.

Current state:
- Cast snapshots track session phase, device, media, and volume.
- Volume 3 planning added a session coordinator, but not ownership semantics.

Gap:
- No `PlaybackOwner` or `SessionOwner` concept.
- No owner transfer rules.
- No analytics ownership rules.
- No recovery model for phone sleep, phone death, cloud URL expiry, NAS
  unavailability, or TV reconnect.

Planning impact:
- Session ownership should become part of Phase 1A/1B contracts before smart
  resume or event-driven remote state sync is claimed.

### 9. Event-Driven Remote Playback State Is Missing

Volume 4 requires the phone to know current media, position, volume, buffer,
health, subtitles, speed, audio, and errors without polling.

Current state:
- Cast and IPTV providers expose streams inside the app process.
- Volume 3 plan added local command/session protocol.

Gap:
- No cross-device event stream contract.
- No playback health event schema.
- No versioned state snapshot/delta model.
- No offline/reconnect replay behavior.

Planning impact:
- The command protocol from Volume 3 needs a companion event protocol for
  playback health and route migration.

### 10. Edge Media Node Is Future Scope, But Needs A Placeholder

Volume 4 introduces a future desktop or home-server Airo installation that can
index media, enrich metadata, monitor streams, schedule recordings, relay
remote access, optionally transcode, and run always-on AI.

Current state:
- The plan lists `airo_home_node`.
- No Edge Media Node capability contract exists.

Gap:
- No capabilities for indexing, relay, transcoding, stream health, recording,
  metadata enrichment, or recommendation serving.
- No trust model for a home node that is more privileged than a phone.
- No remote-access relay policy.

Planning impact:
- Keep Edge Media Node out of v2.0.0.1 implementation, but include its
  capability shape so routing contracts do not need to be rewritten later.

## Required Plan Changes

| Priority | Plan addition | Reason |
| --- | --- | --- |
| P0 | Media Routing Engine contract | Prevents phone-as-default-server architecture |
| P0 | Media location model | Required to choose between cloud, NAS, desktop, TV-local, and phone-local media |
| P0 | Route candidate scoring | Makes route selection deterministic and testable |
| P0 | Playback ownership model | Required for resume, analytics, recovery, and control authority |
| P0 | Secure temporary mobile server contract | Allows phone streaming only for phone-only media |
| P1 | Media capability detection | Required for compatibility checks and alternative-route selection |
| P1 | Device media capability profile | Adds decoder, HDR, audio, network, battery, and thermal signals |
| P1 | Route health events | Required for event-driven remote state and adaptive recovery |
| P2 | Edge Media Node placeholder | Keeps future home-node work compatible without implementing it now |

## Recommended v2.0.0.1 Scope Adjustment

1. Add Media Routing Engine as a foundation contract after connected-device
   discovery and before Lite Receiver playback delegation.
2. Make direct cloud/IPTV URL playback the first supported strategy.
3. Define, but do not implement, NAS, desktop relay, TV USB, and Edge Media Node
   routes in v2.0.0.1.
4. Treat phone-hosted streaming as restricted and last-resort. It requires
   explicit security, battery, thermal, range-request, and shutdown acceptance
   criteria before implementation.
5. Require route decisions to be explainable in logs and tests without leaking
   media URLs or credentials.

## Acceptance Gaps To Add

- Given IPTV or VOD media with a playable URL, the route engine selects direct
  destination playback and does not start a phone media server.
- Given media that exists only on the phone, the route engine may select a
  temporary mobile server only if battery, thermal, trust, and LAN conditions
  pass.
- Given battery below 20 percent, the phone is not eligible to host media unless
  no alternative route exists and the user explicitly confirms.
- Given a destination that cannot decode a media item, route preflight rejects
  that route before source playback stops.
- Given a selected route, the session records route, owner, source, playback
  device, position, audio, subtitles, volume, and health.
- Given a cloud handoff, NAS handoff, or desktop handoff succeeds, the phone can
  sleep without breaking playback.
- Given a temporary mobile server route, URLs are authenticated, expiring,
  trusted-device scoped, and never broadcast through discovery.
- Given route failure, the system attempts a ranked alternate route or reports a
  typed failure reason.

## Final Assessment

Volume 4 should be added to the Airo TV plan as the architecture that keeps the
platform from becoming a battery-draining cast clone. The correct next step is
not to expand the local proxy. It is to define route planning, media location,
device/media compatibility, session ownership, and secure last-resort mobile
serving as contracts, then let the existing Cast and IPTV player code become
execution adapters behind those contracts.
