# NodeCast TV Issue Gap Analysis for Airo TV V2

## Source Review

Reviewed the open GitHub issues for `technomancer702/nodecast-tv` on 2026-07-16:

- Source: https://github.com/technomancer702/nodecast-tv/issues
- Open issues reviewed: 41
- Purpose: identify repeated mistakes and convert useful lessons into bounded Airo TV v2 work.

This is not a feature-copy plan. NodeCast is a web/server app with Docker, browser, OIDC, FFmpeg, and reverse-proxy concerns. Airo TV v2 is a Flutter BYOC player. We should learn from the failures while preserving our current Play Store-safe scope.

## Pattern Summary

| NodeCast issue pattern | Examples | Lesson for Airo | V2 action |
| --- | --- | --- | --- |
| Playback stops, black screens, codec/hardware confusion | #131, #123, #105, #87 | Users need actionable diagnostics, not generic failure states. Hardware/transcode complexity must not leak into ordinary playback UX. | Covered by CV-001. Added connection/session lifecycle checks. |
| Duplicate provider connections | #129 | A player can appear correct while wasting provider connection slots. Track open/close/dispose order explicitly. | Covered by CV-001 and CV-016. |
| Missing audio/subtitle selection | #140, #122, #72 | Multi-language VOD is a baseline media-player expectation. Preferences alone are not enough; controls must be visible during playback. | Added CV-016. CV-008 remains caption persistence/accessibility. |
| VOD duration and seeking failures | #143, #74 | Recorded live events and VOD need distinct timeline semantics from live streams. Unknown/unseekable streams must be explicit. | Added CV-016. |
| Partial or unmapped EPG | #100, #99, #125 | Guide import success is not enough. Channel-id mapping, non-plain XMLTV delivery, and windowed guide verification must be tested. | Covered by CV-015. Add gzip/direct EPG and channel mapping as future sub-slices if needed. |
| Source/category management confusion | #141, #119, #83, #49 | Large lists need source/category visibility controls, stable ordering, and bulk operations. | Partly CV-010/CV-006. Defer multi-source/Xtream-specific controls unless v2 accepts multi-source. |
| TV/browser navigation gaps | #107, #126, #96, #91, #78, #93 | TV focus cannot be an afterthought. Browser-specific fullscreen/Safari issues are less relevant, but D-pad/focus testing is central. | Covered by CV-008 and CV-015 widget tests. |
| Auth/security footguns | #133, #137, #136, #121, #103, #67 | Credentials must never appear in URLs/logs. Auth mode must be explicit and recoverable. | Current v2 avoids account requirement. Keep redaction gates in every adopted issue. |
| Deployment/reverse-proxy assumptions | #68, #84, #80, #102 | Server/Docker configurability creates a support matrix. Avoid bringing this into v2 app scope. | Reinforces CV-011 not adopted and CV-004/CV-014 deferred. |
| Expansion requests | #70, #1, #109, #112 | DVR, multiview, metadata enrichment, and users/profiles are real but separate roadmap surfaces. | Already deferred in CV-004, CV-007, CV-013, CV-014. |

## Airo Gap Decisions

### Adopt Now

1. **Playback session diagnostics**
   - Add duplicate-session detection and teardown order checks.
   - Prove channel switch/retry leaves one active playback session per surface.
   - Keep raw URLs/credentials out of diagnostics.

2. **Playback track and VOD timeline controls**
   - Add a bounded issue for audio/subtitle selection, VOD duration, seek bounds, and unknown-duration states.
   - Use existing `AiroPlaybackEngine.selectTrack`, `seek`, duration, and fake-engine seams.

3. **Program guide verification**
   - CV-015 already covers XMLTV timetable storage and windowed guide queries.
   - Add future sub-slices only if needed for `.gz` XMLTV fetch/decompression and explicit channel-id mapping UI.

4. **TV focus and bounded rendering**
   - Keep D-pad/focus tests mandatory for guide and playback controls.
   - Do not rely on web-style focus metadata.

### Defer

1. **Multi-source/category management**
   - Useful later, especially source-level visibility and "select all visible" operations.
   - Defer until v2 confirms multi-source UX beyond a single BYOC playlist path.

2. **User/profile permissions**
   - NodeCast users ask for per-user content visibility.
   - This belongs with CV-013 household profiles, not current v2.

3. **VOD metadata enrichment**
   - Useful but outside v2 release hardening.
   - Must not introduce remote metadata providers into current BYOC scope.

### Do Not Bring Into V2

- Docker/server env flags.
- OIDC/local auth mode controls.
- Reverse proxy base-path handling.
- FFmpeg/transcoding and hardware encoder configuration.
- Multi-view.
- Recording/download.

## Concrete Issue Updates Made

- Added `community-voice-16-playback-tracks-vod.md`.
- Updated `COMMUNITY_VOICE_ROADMAP.md` to include CV-016.
- Updated `community-voice-01-self-healing-playback.md` with connection/session lifecycle requirements.

## Follow-Up Watchlist

These are not current tasks, but they should be watched after v2:

- XMLTV `.gz` and direct EPG URL support.
- Channel-id mapping UI for playlists whose channel ids do not match XMLTV ids.
- Source visibility and bulk content management.
- Profile-scoped content visibility.
- Metadata enrichment for VOD after local search is stable.
