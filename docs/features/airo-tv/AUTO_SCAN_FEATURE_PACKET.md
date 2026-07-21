# Auto Scan: Stream Availability Cleanup

**Parent issue:** #969 — stream health checker  
**Roadmap:** #958, P0 item 3 (per-stream health check and failover)  
**Base verified:** `origin/main` at `dbbdec9e0165be07df02ff83e7eb2a6b72bdb451` on 2026-07-22  
**Layer:** Mixed — reusable stream-probe contract plus the Airo TV browse workflow

## Feature Packet

**Primary owner agent:** Media Intelligence Architect  
**Review agents:** Playback Architect, TV Experience Architect, Chief Architect, Chief Security Officer, Chief Performance Officer, Chief QA Officer, Product Manager  
**Impacted modules:** `platform_streams`, `platform_worker_jobs`, `feature_iptv`

### Objective

People with large, user-supplied channel lists need a quick way to find stream
URLs that cannot currently be reached, within the channels they are already
browsing. A scan should make availability visible without interrupting playback
or permanently changing a user-owned playlist.

### Critical Agent Gate

**Problem:** An unavailable stream leaves users to discover failures one channel
at a time; lists with thousands of channels make this impractical.  
**User / actor:** An Airo TV viewer managing their own M3U or configured source.  
**Framework or application layer:** Mixed. Stream-probe semantics and resource
scheduling are reusable platform behavior; filtering, review, and undo are Airo
TV product behavior.  
**Owning agent:** Media Intelligence Architect.  
**Reviewing agents:** Listed above.  
**Impacted modules/files:** `platform_streams` probe contract/batcher;
`platform_worker_jobs` scheduling adapter only if the existing generic adapter
cannot schedule a cancellable `streamHealthProbe`; `feature_iptv` providers,
TV toolbar/status UI, and tests.  
**Base branch/worktree:** yes — current `HEAD` equals fetched `origin/main`.  
**Open questions:** None for v1. “Remove” is deliberately a reversible,
filter-scoped display action, not an edit to a source playlist.  
**Decision:** Ready.

### Product Decisions

- The Scan action operates on the exact visible `filteredChannelsProvider`
  snapshot when it starts, including category, taste, search, and hidden-group
  filters. Recent-only mode is a separate explicit scope.
- A short HTTP(S) `GET` with `Range: bytes=0-1023` is the availability probe.
  `HEAD` is not used because common media origins reject it. The request carries
  the channel’s configured user-agent/referrer headers and never logs them.
- A `2xx` or `206` response is **available**. A timeout, DNS/socket failure, or
  terminal non-auth HTTP failure is **unavailable** after one transient retry.
  `401`, `403`, `423`, `426`, and `451` are **restricted**, not dead, and can
  never be removed by this action. Unsupported schemes are **unverified**.
- The currently playing channel is treated as available and is not probed; the
  scan never creates another player/controller. This avoids disrupting viewing.
- The scan is cancellable. It uses one in-flight request while playback is
  active and up to three while idle; each request has a five-second deadline and
  reads at most 1 KiB. Scheduler decisions may defer or throttle it under
  pressure.
- Scan results and removals live only in the current browse session and filter
  fingerprint. Remove hides only the unavailable channels in that scope;
  Restore clears the hide set. Changing the filter discards that scope, so no
  playlist, source credential, channel record, favorite, history, or sync data
  is modified.
- UI uses an icon plus text and semantics, not red/green alone. The TV toolbar
  presents Scan, progress, and then “Remove unavailable (N)” or Restore. A
  compact status summary appears beside the visible/total count.

### Cross-Agent Contract

**Provider agent:** Playback Architect (`platform_streams`)  
**Consumer agent:** Media Intelligence Architect (`feature_iptv`)  
**Interface/API:** A cancellable batch probe accepts URL, safe request headers,
stable channel ID, timeout, and concurrency policy; emits stable-ID keyed
`available`, `unavailable`, `restricted`, or `unverified` outcomes plus progress.
No raw URL, headers, channel title, or provider payload may appear in public
diagnostics.  
**Input shape:** Snapshot of channel IDs, stream URIs, and in-memory headers;
the filter fingerprint is application-only and is never sent to the scheduler.  
**Output shape:** Per-stable-ID result, aggregate counts, `running`, `complete`,
`cancelled`, and `deferred` states.  
**State changes:** The app owns session-local scan state and hide/restore sets;
the platform probe owns no playlist or user data.  
**Errors:** Probe transport failures become an outcome. A scheduler rejection or
cancel preserves the current list and exposes a retryable message.  
**Permissions:** Existing network permission only; no new runtime permission.  
**Privacy/redaction:** URLs and request headers are used in memory only and are
excluded from logs, scheduler stable IDs, analytics, and persistence.  
**Persistence:** None in v1.  
**Versioning/migration:** Additive v1 contract; no schema migration.  
**Tests required:** Platform result classification, retry/cancellation/concurrency
limits, scheduler decisions, app scope/remove/restore behavior, and TV semantics.

## Deterministic Use Cases

### UC-001: Scan the current category

**Actor:** Viewer  
**Preconditions:** News filter shows three user-owned channels; two return 206
and one times out twice.  
**Trigger:** Viewer selects Scan.  
**Happy path:** Progress reaches 3/3; the first two are available and the
timed-out channel is unavailable. Remove hides exactly that one from News.  
**Alternate paths:** Restore returns it immediately; changing to Sports shows
the unmodified Sports list.  
**Failure paths:** Cancelling retains all channels and clears pending status.  
**Data created/updated/deleted:** In-memory scan snapshot and hide set only.  
**Privacy expectations:** No stream URL/header is persisted or emitted.

### UC-002: Continue watching while scanning

**Actor:** Viewer currently playing a channel.  
**Preconditions:** Playback is active and the visible scope contains the playing
channel plus two others.  
**Trigger:** Viewer selects Scan.  
**Happy path:** The playing channel is immediately available without a second
request; remaining requests run one at a time and playback remains untouched.  
**Failure paths:** A pressure/scheduler deferral pauses or cancels scanning with
the list unchanged.

### UC-003: Do not misclassify access restrictions

**Actor:** Viewer scanning a list containing a geo-restricted channel.  
**Preconditions:** The stream responds `451`.  
**Trigger:** Scan completes.  
**Happy path:** The channel is labeled Restricted, is excluded from the remove
count, and remains visible.  
**Failure paths:** A malformed/non-HTTP URI is Unverified and remains visible.

## Automation Flow

### AUTO-001: Filter-scoped scan and undo (host-only)

**Given:** A fake probe returns `available`, `unavailable`, and `restricted`
for a fixed channel snapshot.  
**When:** The application starts a News-filter scan, completes it, removes
unavailable entries, restores them, then changes the filter.  
**Then:** Only the unavailable News ID is temporarily hidden; restricted IDs
remain; Restore and filter change both return the original list.  
**Fixtures:** Three deterministic `IPTVChannel` values and a fake probe.  
**Mocks/stubs:** Clock, probe transport, and worker scheduler.  
**Assertions:** Exact IDs/counts, no source mutation, no raw URL in diagnostics.  
**Cleanup:** Dispose the provider container and cancel token.

### AUTO-002: Playback-safe bounded probe (host-only)

**Given:** Active playback and a fake transport that records concurrent calls.  
**When:** A three-channel scan starts.  
**Then:** The playing ID is not requested and peak transport concurrency is one.  
**Fixtures:** Fixed playback state and three probe responses.  
**Assertions:** No player construction, no request for the playing URL, and
completion progress is 3/3.

## Implementation Plan

### Task 1: Reusable availability probe (M)

- Define the redacted result/state contract and a cancellable, bounded batch
  coordinator in `platform_streams`; exercise classification, retry, progress,
  cancellation, and concurrency with fake transport tests.
- Verify: focused `platform_streams` tests and static analysis.

### Task 2: Airo TV scan state and scheduler bridge (M)

- Add a feature-owned Riverpod controller that snapshots the current filtered
  IDs, maps playback to safe concurrency, consumes the existing worker-job
  policy, and applies session/filter-scoped hide/restore state.
- Verify: provider tests for scope, restrictions, cancellation, and restore.

### Task 3: TV Explorer controls and accessible status (M)

- Add TV-focus-safe Scan/Remove/Restore controls to the existing browse toolbar
  and a text-backed progress/status summary; retain grid/list behavior and
  focus order.
- Verify: targeted widget tests for labels, enabled states, counts, and remote
  semantics.

### Task 4: Feature evidence and focused validation (S)

- Update #969 and the Airo TV feature documentation with the final contract,
  tests, and rollback behavior. Run formatter, targeted package tests, focused
  analysis, and `git diff --check`; no Android emulator and no remote CI for
  this iterative slice.

## Boundaries and Rollback

- **Always:** retain user-supplied source data; use existing safe headers;
  cancel work on dispose/filter change; use host-only deterministic tests.
- **Ask first:** persistence beyond the current session, changing a playlist,
  adding a dependency, or changing player/failover behavior.
- **Never:** make `HEAD` the sole check, instantiate a player per channel,
  log raw URLs/headers, classify access restrictions as dead, or trigger broad
  remote CI for this slice.
- **Rollback:** remove the additive toolbar/controller/probe integration. No
  migration, stored data, or source mutation exists to unwind.

## Success Criteria

1. A viewer can scan only their current visible channel scope and see bounded
   progress without interrupting playback.
2. Available, unavailable, restricted, and unverified outcomes are distinct;
   only unavailable channels are eligible for temporary removal.
3. Remove and Restore are exact, immediate, and neither permanently changes a
   playlist nor leaks across a filter change.
4. The platform/app boundary, privacy posture, cancellation, and TV
   accessibility behavior are covered by deterministic host-only tests.

## Implementation Evidence (2026-07-22)

- Implemented the reusable `platform_streams` availability batcher and a
  feature-level Dio transport using a range request, short timeouts,
  cancellation, and redacted stable channel IDs.
- Added filter-scoped Riverpod state with temporary Remove/Restore behavior;
  no playlist, favorite, history, credential, or synced record is changed.
- Added TV toolbar controls, text-backed per-channel availability badges, and
  focus-safe wrapping at constrained widths.
- Host-only validation: `platform_streams` unit tests and analysis; focused
  `feature_iptv` controller, provider, and full TV-screen widget tests.
