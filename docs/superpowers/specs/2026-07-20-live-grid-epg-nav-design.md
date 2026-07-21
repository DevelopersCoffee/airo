# Live Grid Navigation (EPG) — Design

Status: Draft (spec self-reviewed, pending user review)
Owner: Airo TV mobile + TV guide surfaces (feature_iptv)
Related: `docs/superpowers/plans/2026-07-17-cv015-slice2-epg-grid.md` (predecessor EPG grid work — shipped `EpgTimelineGrid` + `guide_providers.dart`), `docs/superpowers/specs/2026-07-19-immediate-action-player-design.md` (predecessor Player spec — this spec reuses its `/iptv?channel=<id>` deep-link route for reminder notification taps)

## Background

Market scan (same sources as the Player spec, re-confirmed 2026-07-20 — see
Sources) establishes the 2026 norms this spec designs against:

- Mobile streaming apps use a bottom tab bar of 4–5 primary destinations;
  Airo's phone shell already ships exactly this (Home, Live, Guide, Favorites,
  Settings via `AppShell`'s `NavigationBar`), so Requirement 5 reduces to
  verifying/fixing back-button behavior, not rebuilding navigation chrome.
- Live guides on phone are free-drag-scrollable timelines (Pluto TV, YouTube
  TV); on TV they are focus-traversal grids. The interaction models are
  surface-native and must not be forced into one widget ("each surface needs
  platform-native conventions, not the same UI scaled").
- Time-to-content is the guiding metric: a sticky "jump to now" affordance
  and at-a-glance progress state are the difference between a grid that
  feels live and one that feels like a static table.

The repo already has the shared data foundation: CV-015 slice 2 shipped
`guide_providers.dart` (`guideEpgWindowProvider` with match-override
remapping) and `EpgTimelineGrid`, a D-pad/focus-driven timeline grid used by
`IptvGuideScreen` on both TV and (adapted) phone. That grid is deliberately
focus-only — every row uses `NeverScrollableScrollPhysics`, scroll follows
focus — so it cannot satisfy phone touch interaction. This spec adds a
separate touch interaction implementation over the same data layer, plus the
now-anchor, progress tickers, and phone-only reminders. TV keeps its
receiver-only role: it gains the shared grid improvements (progress ticker,
jump-to-present) but no scheduling/notification surface.

Sources:
- https://blog.mercury.io/designing-great-streaming-tv-apps-pt-1-introduction/
- https://www.forasoft.com/blog/article/streaming-app-ux-best-practices

## Goals

1. **Time-axis scrolling (both surfaces).** Horizontal timeline of scheduled
   programming paired with a vertical channel list. Phone: free two-axis
   drag scroll over a window spanning `now-30min … now+24h`, loaded in
   3-hour pages as the user scrolls. TV: existing focus-follow-scroll,
   unchanged in feel.
2. **"Now Playing" anchor (both surfaces).** A "Jump to Present" control
   snaps the grid back to the current time slot — a sticky extended FAB on
   phone (visible only when `now` is scrolled out of the viewport), a
   focusable header button on TV.
3. **Visual progress tickers (both surfaces).** Current program blocks show
   a live progress fill and a "N min left" label, driven by a shared 30s
   `nowTickerProvider`; the existing now-line indicator is retained.
4. **Notification reminders (phone only).** One tap on a future program
   block schedules an OS local notification (via
   `flutter_local_notifications`, already an `app` dependency) at program
   start; tapping the notification opens the channel directly via the
   existing `/iptv?channel=<id>` deep link. Tapping a currently-airing
   block plays the channel immediately (consistent with the Immediate
   Action Player: no interstitial). Reminders persist across restarts and
   are pruned once elapsed.
5. **Navigation norms (phone only).** The existing Material 3
   `NavigationBar` with the Guide tab is retained (matches the 4–5 tab
   norm). Android hardware back and iOS swipe-back from the guide follow
   the standard route stack — verified and fixed where broken; no
   Cupertino rework.

## Non-Goals

- TV-side reminders, scheduling, or any notification surface — TV is
  receiver-only per the Core TV Device-Role Principle. Requirements 4–5 do
  not touch `iptv_tv_screen.dart` or the TV nav shell.
- A single unified grid widget with an interaction-mode parameter —
  rejected in favor of two widgets over one data layer, so each interaction
  model evolves independently and TV focus traversal cannot regress from
  phone work.
- Xtream/Stalker EPG ingestion, catch-up/timeshift from guide cells —
  carried over as non-goals from CV-015 slice 2.
- Past browsing beyond `now-30min` — past blocks are dimmed and
  non-interactive; the timeline floor is fixed.
- `platform_epg` changes — `loadWindow(GuideWindowQuery)` already supports
  arbitrary windows; pagination is an application-layer concern.

## Architecture

Three layers, same shape as the Player feature (application coordinators
over platform primitives):

- **`platform_epg`** — untouched (pure data/model layer per its
  `module.yaml`).
- **`feature_iptv/application`** — new orchestration: paged guide-window
  provider, shared now-ticker, reminder store + scheduler.
- **`feature_iptv/presentation`** — two interaction implementations over
  one data path: existing `EpgTimelineGrid` (TV, D-pad) and new
  `EpgTouchTimelineGrid` (phone, drag/tap). `IptvGuideScreen` selects the
  grid by form factor, as it already adapts chrome via `overrideFormFactor`.

### New components

**`GuidePagedWindowNotifier`** (`feature_iptv/lib/application/providers/guide_providers.dart`, additive)
- Holds loaded 3-hour pages keyed by page start, merged into one
  `CompactEpgWindow` view for consumers.
- Initial load covers `[now-30min, now+6h)`; `extendForward()` loads the
  next 3h page, hard-capped at `now+24h`; the lower bound is fixed at
  `now-30min`.
- Reuses the match-override query+remap logic currently inside
  `guideEpgWindowProvider` — extracted into a shared helper so both query
  paths stay byte-identical in behavior (override application and
  channel-id remapping must not diverge between the two grids).
- A failed page load keeps already-loaded pages and records a per-edge
  error state the UI renders as an inline retry cell (see Error Handling).
- Both grids consume this paged provider's merged window: the phone grid
  drives pagination via its scroll-edge listener, while the TV grid simply
  renders its fixed 3h viewport from the initially loaded pages (a subset)
  and never triggers `extendForward()`. The legacy `guideEpgWindowProvider`
  is superseded by the paged provider and removed once both grids are
  migrated, keeping exactly one data path (Approach A).

**`nowTickerProvider`** (`guide_providers.dart`, additive)
- 30s periodic `StreamProvider<DateTime>` (UTC). Lifts the cadence of the
  existing `_CurrentTimeIndicator`'s private `Timer.periodic` into a shared
  provider so the now-line, progress fills, and "N min left" labels on both
  grids run off one clock.

**`EpgReminderStore`** (`feature_iptv/lib/application/epg_reminder_store.dart`)
- Persisted list of `{channelId, programId, title, startsAt,
  notificationId}` via `core_data`'s `KeyValueStore` as a single JSON blob —
  mirrors `XmltvSourceStore` (reminder counts are small).
- `save/remove/list/pruneElapsed(now)` primitives only; no scheduling
  logic.

**`EpgReminderScheduler`** (`feature_iptv/lib/application/epg_reminder_scheduler.dart`)
- Wraps `flutter_local_notifications` (already in `app/pubspec.yaml`;
  pattern precedent: `app/lib/features/quest/domain/services/reminder_service.dart`).
- `scheduleReminder(program)` — requests OS permission on first use;
  schedules a local notification at `program.startsAt`; persists via
  `EpgReminderStore`. Returns an enum outcome: `scheduled`,
  `scheduledInAppOnly` (permission denied — see Error Handling),
  `unavailable` (`MissingPluginException`, e.g. macOS/web/debug hosts).
- `cancelReminder(programId)` — cancels the OS notification and removes the
  store record.
- `isAvailable` — false on `MissingPluginException`; the UI hides the
  reminder affordance entirely in that case.

**`EpgTouchTimelineGrid`** (`feature_iptv/lib/presentation/widgets/epg_touch_timeline_grid.dart`)
- New phone widget. Two-axis drag scroll: vertical channel list +
  horizontal timeline rows sharing one `ScrollController` with the
  time-axis header (same multi-attachment pattern as the TV grid — read
  extents via `.positions.first`, never `.position` — but with drag physics
  instead of `NeverScrollableScrollPhysics`).
- Sticky channel-label column; program blocks sized by duration using the
  same `pxPerMinute` model as the TV grid (tuned const for phone density).
- Per-current-block progress fill + "N min left" label driven by
  `nowTickerProvider`; past blocks dimmed and non-interactive.
- Tap a currently-airing block → `iptvStreamingServiceProvider.playChannel`
  immediately (no interstitial, per the Player spec). Tap a future block →
  toggle reminder via `EpgReminderScheduler`, with snackbar confirm + Undo.
- Scroll-edge listener triggers `GuidePagedWindowNotifier.extendForward()`.
- Sticky "Jump to Present" extended FAB, visible only when `now` is outside
  the visible time viewport; animates the shared controller back to the now
  offset.

**`EpgTimelineGrid` additions (TV, additive only)**
- Same progress fill + "N min left" rendering inside current blocks
  (visual only), driven by `nowTickerProvider`.
- A focusable "Jump to Present" button in the guide header that re-scrolls
  the shared controller to the now offset. Focus traversal and
  `NeverScrollableScrollPhysics` are unchanged.

### App-shell wiring

- Reminder notification taps resolve through the existing
  `/iptv?channel=<id>` deep-link route (shipped in the Player feature) — no
  new route, no per-source special casing.
- `IptvGuideScreen` renders `EpgTouchTimelineGrid` when the effective form
  factor is phone/tablet, `EpgTimelineGrid` when TV — the same
  `overrideFormFactor` mechanism it already uses.
- Requirement 5 verification: Android hardware back from the guide follows
  the `go_router` stack to the previous tab/exit; iOS back-swipe leaves no
  orphaned grid state (controllers disposed, ticker canceled). Fixes are
  made only where verification finds breakage.

## Data Flow

1. Guide opens → paged provider loads initial pages `[now-30min, now+6h)`
   via the shared override-remap query path; grid renders rows with empty
   timelines while pages stream in.
2. User drags toward the forward edge → scroll listener calls
   `extendForward()` → next 3h page merges → hard stop at `now+24h`;
   backward drag stops at `now-30min`.
3. `nowTickerProvider` ticks every 30s → now-line, progress fills, and
   "N min left" labels recompute; when `now` crosses a block boundary,
   current/past/future block status flips without re-querying EPG data.
4. Tap current block → `playChannel` immediately (Player spec path).
5. Tap future block → `EpgReminderScheduler.scheduleReminder` → (first
   time) OS permission prompt → OS notification at `startsAt` + persisted
   record → snackbar "Reminder set for \<title\>" with Undo →
   `cancelReminder`. Tapping an already-reminded block cancels (toggle).
6. Notification fires → user taps → app opens `/iptv?channel=<id>` → plays
   immediately.
7. On guide open and on app resume, `pruneElapsed` removes reminders whose
   program has ended.

## Error Handling

- **Notification permission denied** → outcome `scheduledInAppOnly`: the
  reminder is persisted and shown in-app (scheduled indicator on the
  block), but no OS notification is scheduled; snackbar explains
  "Notifications are off — reminder will only show in-app." No silent drop,
  no crash.
- **Reminded program disappears after an EPG refresh** → the notification
  still fires with the stored title; the `/iptv?channel=<id>` deep link
  falls back to the browse grid per the Player spec's missing-channel
  handling.
- **`MissingPluginException`** (macOS/web/debug hosts) → `isAvailable`
  false; reminder affordance hidden on future blocks; grid and playback
  unaffected. Matches the existing `native_fullscreen.dart` /
  `AiroNativePictureInPicture` degradation pattern.
- **Page load failure during pagination** → already-loaded pages stay
  rendered; an inline "Couldn't load more guide data — Retry" cell renders
  at the forward edge; retry re-issues the failed page load.
- **EPG unavailable/stale** → existing `_GuideAvailabilityBanner` behavior
  carries over unchanged; rows render with empty timelines.
- **Zero-duration / malformed programs** → progress calculator clamps to
  `[0, 1]`; zero-duration blocks render without a fill (no division by
  zero).

## Testing

- **Unit:** `GuidePagedWindowNotifier` (page merge/dedup, 24h cap, -30min
  floor, failed-page-keeps-loaded-pages, retry); shared override-remap
  helper parity with the existing `guideEpgWindowProvider` behavior;
  `EpgReminderStore` round-trip (mirrors `XmltvSourceStore` tests);
  `EpgReminderScheduler` with a mocked notification plugin (schedule,
  cancel, toggle, permission-denied → `scheduledInAppOnly`,
  `MissingPluginException` → `unavailable`, prune); progress-fraction
  calculator (block straddling window edges, zero-duration guard).
- **Widget (phone):** drag scroll keeps rows + time axis in sync;
  now-anchor FAB appears only when `now` is off-viewport and snaps back on
  tap; tap current block calls `playChannel` with no route push; tap future
  block toggles reminder with snackbar + Undo; progress fill renders on the
  current block only; inline retry cell on page failure.
- **Widget (TV):** "Jump to Present" is focusable via D-pad and re-scrolls
  to now; progress fill renders on current blocks; all existing
  `EpgTimelineGrid` focus/navigation tests still pass unchanged
  (regression gate).
- **Widget (nav):** Android hardware back from the guide follows the
  expected route stack; iOS back-swipe leaves no orphaned state.
- **Manual QA gate (same as the Player feature):** OS notification
  delivery + deep-link tap verified on physical iOS and Android hardware
  before merge — notification behavior is not reliably testable in
  simulator/emulator; flag as a manual gate, not automatable in CI.
