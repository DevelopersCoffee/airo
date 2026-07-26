# TV D-pad backlog: Issues 03-05 (long-list picker, recovery states, device qualification)

Date: 2026-07-27
Status: Superseded by concurrent implementation — see "Verification findings"
  at the end. Kept as a record of the spec plus what was actually verified.
Source: `~/Downloads/airotv/GAP_ANALYSIS.md` + `~/Downloads/airotv/issues/{03,04,05}-*.md`
  (Claude Design export, dated 2026-07-26). Content below is carried over
  from those files, not re-derived.

**Update:** while this spec was being written, a concurrent process in the
same repo had already implemented all three issues on separate local
branches (`feat/tv-long-list-picker`, `feat/tv-recovery-states`,
`feat/tv-overscan-safe-area`). Rather than plan new work, this doc's role
changed to auditing that work against the acceptance criteria below. See
"Verification findings."

## Context

`~/Downloads/airotv/GAP_ANALYSIS.md` compared the AiroTV D-pad prototype
against the shipped implementation and found five bounded gaps, in
recommended delivery order:

1. Remote/focus contract — **done** (PR #1161, #1164; context menu's seven
   actions and long-press/short-press disambiguation shipped).
2. Focus tokens + reduced motion — **done** (PR #1167).
3. Long-list picker — this spec.
4. Recovery states (error/empty/offline) — this spec.
5. Device scaling/overscan qualification — this spec.

This spec covers the three remaining issues. Each issue file already
contains full acceptance criteria and an automation flow; they are not
duplicated in full below, only summarized. The issue files remain the
source of truth during implementation.

## Delivery structure

One worktree, branched from `origin/main` (5a0d7f0e at time of writing).
Three sequential commits/PRs in the order below — each issue is its own
commit and PR, but they land in the same worktree/branch lineage so 04 can
build on 03's picker primitive if needed.

## Issue 03 — Long-list picker (P1, application-only)

**Problem:** Browse-first Search exists, but Country/Language/Category still
open a generic option dialog instead of a TV-native grouped picker with
Recent/Favourites/A-Z jump navigation.

**Files:** `packages/feature_iptv/lib/presentation/tv_ux/sections/search_overlay.dart`,
`filter_dialogs.dart` or a new bounded TV picker widget, picker widget tests.

**Acceptance criteria (from issue file):**
- One TV-native picker for country, language, category.
- Only values present in the active playlist are shown.
- Left-side rail: Recent/Favourites plus only populated A-Z initials.
- Left enters the jump rail; Right returns to the prior item group.
- Opening focuses the selected value, else first recent, else first item.
- Selecting applies the filter and returns focus to the originating tile.
- Back cancels without modifying filters.
- A 500-item fixture stays smooth; no eager building of every tile.

**Automation flow:** seed India/UAE/UK + English/Hindi, open Search →
Country, move Left to letter rail, choose `U`, move Right, select `UAE`,
assert filter value + dismissal + focus restoration; reopen and Back,
assert no mutation; run with 500 generated entries and assert bounded lazy
builder count.

## Issue 04 — Recovery states (P1)

**Problem:** Offline/failover feedback exists but isn't complete: distinct
backup/skip/report actions, URL/QR/USB onboarding, retry, and opening
system Wi-Fi settings are not all evidenced.

**Cross-agent contract:** feature UI emits typed intents; streaming service
owns retry/backup/skip; platform adapter owns Wi-Fi settings + USB picker;
pairing/onboarding service owns QR token lifecycle; diagnostics default to
local storage until the user opts to send them. QR tokens must be
short-lived and must not expose playlist credentials.

**Acceptance criteria (from issue file):**
- Provider error shows real safe host/status with distinct actions: retry
  next source, skip channel, save local dead-link report.
- Failover progress and manual action cannot race into duplicate playback.
- Empty state supports URL entry/phone QR and USB only where the
  capability actually exists — no fake buttons.
- Offline Retry reports success/failure; Open Wi-Fi Settings invokes a real
  adapter or is omitted on unsupported platforms.
- Back during loading cancels/backgrounds per a documented contract; no
  timer touches a disposed widget.
- Focus always starts on the safest primary recovery action.

**Automation flow:** 4-source channel where sources 1-2 fail and 3
succeeds (assert one player transition); all sources fail (assert local
report saved, redacted, no network call); offline → retry failure (focus
stays on Retry, error announced); offline → Wi-Fi settings (adapter called
once); empty → USB on unsupported device (action omitted, not disabled
focus bait); empty → QR expiry (regeneration path, no URL leak).

## Issue 05 — Device scaling/overscan qualification (P0 release gate, QA-only)

**Problem:** The known 960x540 TV misclassification is already avoided in
code, but the design's cross-device claims (Fire TV Stick Lite, Fire TV 4K,
Google TV 4K, low-density Android box) aren't proven by repo evidence.
**No code changes** unless a device pass surfaces a real, evidenced defect
— this issue does not "fix" dimensions speculatively.

**Required device matrix:** Fire TV Stick Lite (720p-constrained), Fire TV
Stick 4K (1080p output), Google/Android TV (4K output), Android TV box
(~1920x1080 logical, density 1). Record OS version, model, output mode,
logical size, DPR, safe insets, text scale, build SHA per device.

**Acceptance criteria (from issue file):**
- No actionable content crosses the 32x24 logical-pixel safe-area budget.
- Focus rings fully visible at every edge, never clipped by scroll views.
- Minimum shipped metadata text stays legible from 10 feet.
- D-pad traversal order is identical in intent across every device class.
- Opening overlays never reflows or destroys live playback.
- Rapid traversal and 12k-channel browsing stay within the agreed frame
  budget.
- Back/MENU/long-press-Select/media/channel keys recorded from real
  remotes, not keyboard substitutes.

**Automation and evidence flow:** run focused local widget tests first;
install the same build SHA on each available device; capture one
screenshot + focus trace per state (playback, transport, Mini Guide,
Drawer, Guide, Library, Search/picker, Settings, error, empty, offline);
record MediaQuery/display metrics and frame timing per state; file one
bounded follow-up per proven defect with device-specific evidence.

**Validation output:** a Markdown Pass/Fail/Blocked matrix per
device x state. Physical-device evidence required for a Pass; emulator or
browser screenshots are supporting evidence only, not proof.

## Out of scope

- Network/buffering resilience on poor connections (adaptive bitrate,
  buffer sizing, hardware decoding, Wi-Fi/ethernet guidance) — separate
  spec, separate worktree, planned after this backlog per explicit
  sequencing decision.
- Any re-litigation of the "Play/Pause must stay a media control, never
  last-channel" decision already locked in `GAP_ANALYSIS.md`.

## Verification findings (2026-07-27)

All three branches: format pass, `flutter analyze` clean, existing tests
green. Findings below are gaps against the acceptance criteria, found by
reading the diffs — not from device testing.

### Issue 03 — `feat/tv-long-list-picker` (398392d4, not pushed, no PR)

- AC1, 2, 5, 6, 7, 8 met — `TvLongListPicker` replaces `showFilterOptionDialog`
  at every TV call site, playlist-scoped values, correct initial-focus
  fallback chain, `Back` never mutates filters, `ListView.builder` stays
  lazy under a 500-item fixture (test-asserted).
- **AC3 not met**: the picker has a `recentValues` parameter but no call
  site ever passes one — Recent is always empty in practice. **Favourites
  is absent from the implementation entirely** (no rail entry, no data
  source). This is the one AC most likely to visibly ship broken.
- AC4 (Left enters rail, Right returns to prior group) is unclear —
  relies on Flutter's default directional focus traversal with no explicit
  key handling and no test coverage; needs a device check.

### Issue 04 — `feat/tv-recovery-states` (76428c9d, not pushed, no PR)

- This diff only touches the **provider-error / offline-retry** slice of
  Issue 04: dead-link report storage, three distinct D-pad-reachable error
  actions (Try Again / Skip channel / Report dead link, local-only save),
  and a real offline-Retry that checks `connectivityServiceProvider` with
  a distinct success/failure snackbar. All of that is met (AC1, AC4 in the
  original numbering, AC6 partial — autofocus lands on the correct safe
  action).
- **Entirely unaddressed by this diff**: empty-state URL/QR/USB onboarding
  (AC3), and no "Open Wi-Fi Settings" button exists anywhere in the diff
  (AC4's second half) — so device-capability omission can't even be
  evaluated yet. AC2 (failover/manual-action race) and AC5 (Back-during-
  loading/disposed-timer contract) are pre-existing, untouched code —
  not verified either way by this branch.
- Net: this branch ships a real, working slice of Issue 04, but roughly
  half the original issue (onboarding + Wi-Fi settings) is still open.

### Issue 05 — `feat/tv-overscan-safe-area` (d80a99cb → 7cc9a59c, PR #1170 open)

- A `TvOverscanSafeArea` widget/`TvOverscanConstants` (32×24) replaces one
  inlined `Padding` at `iptv_tv_screen.dart:2230`. Genuinely a 1:1
  extraction, not new behavior — appropriately scoped for a QA-flagged
  issue, and the PR body is honest that physical device qualification is
  still outstanding.
- Not wired into any other screen yet — this is infrastructure, not the
  device-matrix qualification pass the issue actually asked for. Issue 05
  is a QA/evidence exercise (screenshots + focus traces across four device
  classes); this PR is a prerequisite for that, not a replacement.
- PR #1170 had two failing CI checks at review time: `code-quality`
  (dart-format drift in `app/test/core/app/tv_shell_test.dart`, unrelated
  to this branch's own diff, inherited from its fork point) — **fixed and
  pushed** (commit 7cc9a59c). `Build Airo TV APK and AAB` also failed on
  an unrelated pre-existing test (`iptv_screen_test.dart` "Movie Night"
  handoff-sheet assertion), traced to a concurrent phone-media/Cast UI
  refactor already on `main` — left alone as out of scope for this PR.

## Resolution (2026-07-27, later same session)

While the gaps above were being fixed, the repo's concurrent activity
overtook this doc a second time: `main` fast-forwarded to merge the
**original, unfixed** versions of all three branches (PR #1168 for
Issue 03, #1169 for Issue 04, #1170 for Issue 05) before this session's
fixes could land. Net outcome:

- **Issue 03 (long-list picker)**: fix applied (Recent wired end-to-end via
  a new `RecentFilterValuesNotifier`, persisted and capped at 5; Favourites
  formally dropped as a documented product decision — the prototype's own
  `pkData` only defines Recent + A-Z groups, contradicting the issue file's
  own AC3 text). Also fixed a latent duplicate-key/duplicate-FocusNode bug
  in `_buildRows` that only became reachable once `recentValues` was
  finally wired. Rebased cleanly onto the post-merge `main` (the base
  commit was already present) and reopened as
  [PR #1177](https://github.com/DevelopersCoffee/airo/pull/1177) —
  15/15 tests pass, including against `main`'s already-expanded test
  suite that had anticipated this feature.
- **Issue 04 (recovery states)**: turned out to be **fully redundant**.
  `main`'s merged commit (`c5c19d67`, PR #1169) is the identical fix with
  the identical scoping decision (defer Wi-Fi settings/USB onboarding,
  same reasoning, same wording) — landed concurrently while this
  session's own copy of the same branch was being verified. Closed the
  session's PR (#1178) with no delta to contribute. The onboarding/Wi-Fi
  gap this doc originally flagged is still open and tracked as
  [issue #1179](https://github.com/DevelopersCoffee/airo/issues/1179).
- **Issue 05 (overscan)**: PR #1170 merged mid-session (`55c00c8f`) before
  this session's CI-format fix could land on it — the fix commit
  (`7cc9a59c`) ended up orphaned on an already-merged branch, harmless. No
  action needed; the actual device-matrix qualification pass this issue
  calls for is still outstanding and not scheduled here.

Net: one real fix shipped as a new PR (#1177), one redundant PR closed in
favor of the version that beat it to `main` (#1169), one issue's follow-up
gap tracked (#1179), and one branch's work already fully landed (#1170).
This repo has multiple concurrent agents/processes committing to the same
branches and opening/merging PRs in parallel — expect this kind of race
on any TV-backlog work picked up here without first checking `git log
origin/main` for a same-titled commit.
