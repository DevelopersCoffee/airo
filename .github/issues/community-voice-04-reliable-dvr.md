---
name: Agent Task
about: Deferred community request
title: '[DEFERRED] CV-004: DVR and Background Recording'
labels: 'agent/media, P2, enhancement, community-voice, v2-deferred'
assignees: ''
---

## V2 Milestone Decision

**Decision:** Defer from current v2.

**Reason:** DVR requires background execution, storage policy, recording-rights UX, file writing, failure recovery, and possibly SMB/NAS support. That is too large and too permission-sensitive for v2 Play Store hardening.

## What To Keep From The Community Request

- Users care about reliable scheduled recording and recovery from stream interruptions.
- Preflight checks for stream availability and storage are essential.
- Recording should be chunked and recoverable rather than one fragile long file.
- Worker boundaries are the correct place for heavy recording work.

## What Not To Build In Current V2

- No background DVR service.
- No SMB/NFS recording.
- No broad storage permission.
- No scheduled recording UI.
- No file stitching pipeline.

## Future Feature Packet Gate

**Problem:** Users want reliable recording of authorized live streams.
**User / actor:** User scheduling a recording for a channel from their own playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Media Agent.
**Reviewing agents:** Framework Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent.
**Impacted modules/files:** `packages/platform_worker_jobs`, `packages/platform_player`, `packages/platform_streams`, `packages/platform_playlist_export`, `packages/feature_iptv`.
**Base branch/worktree:** Must be reconfirmed from latest `origin/main` when reopened.
**Open questions:** Legal/product posture, Android background limits, storage location, file format, network-share support.
**Decision:** Blocked until recording policy and permission design are approved.

## Future Cross-Agent Contract Required

**Provider agent:** Media Agent.
**Consumer agent:** Mobile UI Agent.
**Interface/API:** Recording scheduler, recorder worker, storage adapter, preflight validator.
**Input shape:** Channel URL, schedule time, duration, output target, user confirmation.
**Output shape:** Recording job state, partial chunk state, final file metadata.
**State changes:** Local job queue and output files.
**Errors:** Storage unavailable, stream unavailable, permission denied, partial recording, chunk corruption.
**Permissions:** Storage/background permission only after explicit review.
**Privacy/redaction:** Recording metadata must not expose credentialed URLs.
**Persistence:** Local recording jobs and files.
**Versioning/migration:** Job schema and cleanup policy required.
**Tests required:** Preflight, chunk retry, cancellation, cleanup, storage failure.

## Reopen Criteria

- Play Store/storage policy review is complete.
- Recording rights UX is specified.
- First slice is limited to local manual recording preflight or recorder spike.
