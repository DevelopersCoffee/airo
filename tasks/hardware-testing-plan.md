# Hardware Testing Plan: Issue-by-Issue Associate Developer Handoff

Date: 2026-07-27

Planning branch: `codex/hardware-testing-plan-20260727`

Planning worktree: `/Users/udaychauhan/workspace/airo-worktrees/hardware-testing-plan`

Base: `origin/main` at `34d13b941e9e08e2c43543174374a82cd7515dba`

## Purpose

This document turns the Fire TV and real-device issues named in the supplied
text into independent QA assignments. It is a plan only: no build, install,
device connection, or test run was performed while preparing it.

The most important distinction is:

- **Fire TV app testing** means installing Airo TV on Fire TV and driving it
  with the Fire remote. That is useful for #589 and later release
  qualification.
- **Google Cast receiver testing** means the phone discovers a receiver that
  advertises `_googlecast._tcp.local`. That is required for #889 and #459.
  An Amazon Cast-only Fire TV is not a valid receiver for these tests.
- **Airo-native receiver testing** is future milestone-10 work. Do not claim
  that the current Google Cast baseline proves it.

## Critical Agent Clarity Gate

**Problem:** Several issues ask for physical-device evidence, but their
protocols, artifacts, devices, and closure gates differ. Treating them as one
Fire TV campaign would produce invalid evidence.

**User / actor:** Associate software developer acting as a physical-device QA
operator and evidence recorder.

**Layer:** QA and release evidence. No framework or application implementation
is authorized by this plan.

**Primary owner:** Chief QA Officer / QA Automation Agent.

**Issue-specific owners and reviewers:**

- #889: Playback Architect owns the streaming contract; Chief QA Officer owns
  the matrix evidence; Security reviews redaction.
- #589: TV Experience Architect owns focus/remote behavior; Flutter Architect,
  Chief UX Officer, and Chief QA Officer review.
- #459: Chief QA Officer owns the Cast V1 matrix; Playback/Media and Release
  review.
- #683: Chief Release/DevOps Officer owns the final release gate; Chief QA
  Officer and device-domain owners review.
- #1081: Observability/Release/QA own the launch gate; Playback, Platform,
  Security, UX, and Product review the affected contracts.

**Decision:** Ready for planning and delegation. Each actual test run must use
its own issue branch/worktree synced from the then-current `origin/main`.

## Current Issue Map

| Issue | What it expects | Correct hardware | Can an associate start it now? | Completion evidence |
| --- | --- | --- | --- | --- |
| #889, CV-033 dogfood | Execute the 12-item local-file phone-hosted streaming matrix. | Android phone plus a real Google Cast receiver such as Chromecast, Google TV, or Cast-capable Sony BRAVIA; real ~5 GB H.264/AAC MP4; unsupported file; same Wi-Fi. | **Yes, if all prerequisites are present.** Fixes #1155, #1156, and #1157 are closed, but the tested build must contain them. | Updated `docs/release/evidence/cv-033-device-dogfood.md`, sanitized logs/photos, timings, storage/battery/thermal observations, issue comment, and a follow-up issue per failure. |
| #589, IPTV TV UI/UX | Prove physical D-pad reachability, visible focus, Help operation, and no focus/overflow/render failures. | Fire TV or Android TV with physical remote; Airo TV `tv` build installed. Google Cast is not required. | **Yes.** This is the best independent Fire TV assignment. | Sanitized D-pad JSON/Markdown report, device/build metadata, traversal notes, and comment on #589. |
| #459, Google Cast V1 QA | Complete sender-to-receiver Cast discovery, HLS playback, stop/disconnect/network/background cases. | Android phone, iPhone, and a Chromecast-enabled TV/Google TV/BRAVIA on shared Wi-Fi. | **Yes, when both sender platforms are available.** Android-only work is partial evidence, not closure. | Build and OS versions, receiver model/OS, channel ID, screenshots, pass/fail notes, and bugs linked to #459. |
| #683, release qualification | Qualify the exact final APK/AAB release artifact for every required device class or record approved waivers. | Selected phone, tablet/wide layout, Android/Google TV, Fire TV, or managed-device matrix. | **Not until the release owner supplies the final artifact, checksum, required device list, and waiver rules.** | Release qualification evidence JSON and report containing exact filename, SHA256, package/profile, model, OS, result, and approved waiver details. |
| #1081, M10 launch gate | Prove redacted diagnostics, low-end/weak-Wi-Fi qualification, install/recovery guidance, flag behavior, and rollout metrics. | Supported Airo-native receiver classes across the approved Android TV/Google TV/Fire TV matrix. | **No. Blocked by #889 and #1076-#1080.** Hardware evidence alone cannot close it. | Passing qualification matrix plus diagnostics, feature flag, guidance, and testable rollout metrics. |
| #1084, M10 tracker | Roll up the state of all milestone-10 slices. | None directly. | **No separate test assignment.** | Update only after child issues have authoritative evidence. |

## Issues That Are Context, Not New Assignments

- **#1151 is closed.** It corrected #889 so Amazon Cast-only Fire TV is
  explicitly protocol-incompatible with the Google Cast baseline.
- **#844 is closed.** It proves the host-tested CV-033 runtime baseline. It does
  not replace #889 physical evidence.
- **#590 is closed.** Its active-receiver channel-switch implementation and
  report tooling can support regression evidence, but do not reopen it merely
  to run #459.
- **#598 is closed.** It defined the reusable legacy certification contract.
  The remaining physical release evidence belongs to #683.
- **#1155, #1156, and #1157 are closed.** They addressed the source-handle,
  token-logging, and stale-playing failures found during the partial #889 run.
  Their closure allows a fresh #889 rerun; it does not prove the rerun passes.

## Dependency and Execution Order

```text
Independent device evidence
├── #589 Fire TV / Android TV D-pad pass ───────────────┐
├── #459 Android + iOS Google Cast V1 pass ────────────┤
└── #889 Android phone → Google Cast local-file pass ──┤
                                                       │
Final signed/release artifact + release-owner decisions│
                                                       ▼
                                                    #683

#889 + #1076 + #1077 + #1091 + #1078 + #1092 + #1079 + #1080
                                                       ▼
                                                    #1081
                                                       ▼
                                                    #1084
```

Run #589, #459, and #889 as separate campaigns. They may share devices, but
they must not share conclusions because they test different contracts.

## Expanded Campaign: Airo TV Physical Device QA Pass

This campaign adds the maintainer-supplied
`issues/05-device-scaling-overscan.md` qualification contract and physical
verification for merged PRs #1177, #1188, #1190, and #1237. “Issue 05” here is
the supplied backlog-file identifier, not GitHub issue #5. The referenced
backlog file is not present on current `main`, so the matrix and acceptance
criteria supplied with this request are the authoritative QA contract.

The current planning base contains all relevant merge commits:

| Change | Merge commit | Physical gap |
| --- | --- | --- |
| PR #1170, shared 32×24 overscan primitive | `55c00c8f` | Full physical matrix, edge focus, remote, and performance evidence |
| PR #1177, TV long-list picker | `81e007f8` | Real D-pad jump-rail traversal and large-list smoothness |
| PR #1188, Wi-Fi Settings action | `bd4d9e24` | OEM-specific Android settings launch and clean app return |
| PR #1190, QR phone handoff | `a515f9e8` | Real TV-to-phone LAN form, submission, and expiry |
| PR #1237, sustained-stall failover | `34d13b94` | Real degraded-network failover, terminal error, and transient rebuffer behavior |

All five changes have automated coverage. None of that automated coverage is a
physical-device pass.

### Relationship to the other assignments

- This campaign includes and broadens #589’s physical D-pad slice. If the full
  matrix is executed, do not repeat the same #589 traversal separately; link
  the relevant rows and generated D-pad reports to #589.
- Results may contribute to #683 only when the exact tested artifact is also
  the release artifact named and hashed by #683. A debug build does not qualify
  a different release APK/AAB.
- This campaign does not satisfy #459 or #889. Those require a phone acting as
  a Google Cast sender and test different protocols.

### Required physical device matrix

| Matrix ID | Required class | Required output/profile |
| --- | --- | --- |
| `fire-tv-lite-720p` | Fire TV Stick Lite or equivalent constrained device | 720p |
| `fire-tv-4k-1080p` | Fire TV Stick 4K | Forced/configured 1080p output |
| `google-android-tv-4k` | Google TV or Android TV | 4K output |
| `android-tv-density1-1080p` | Android TV box | Approximately 1920×1080 logical pixels at DPR/density 1 |

Do not replace a missing class with an emulator, browser viewport, or another
physical class and call it passed. Record `EVIDENCE GAP` for the unavailable
class. Emulator/browser screenshots may support layout diagnosis only.

The entire campaign can be marked `PASS` only when every required physical
class is present and every mandatory row passes. Otherwise report per-device
results and mark the campaign `INCOMPLETE` or `FAILED`, as applicable.

### Metadata required for every device

Record before testing:

- device matrix ID and public device label;
- manufacturer/model;
- Fire OS or Android/Google TV OS version and build;
- configured display output mode;
- Flutter logical width and height;
- device pixel ratio (DPR);
- safe insets on all four sides;
- text scale;
- Airo Git build SHA;
- APK filename and SHA256;
- package ID and build mode;
- physical remote model/type;
- test date and tester.

Use an existing in-app diagnostic surface or approved device diagnostics to
capture MediaQuery values. Do not infer logical size, DPR, safe insets, or text
scale from the television’s advertised output resolution. If the tested build
cannot expose one of these values, record an evidence gap and file a focused
instrumentation issue; do not add instrumentation during the QA run.

### Common physical qualification on every matrix device

#### Safe area, focus, and 10-foot UX

- No button, focus target, or text crosses the 32×24 logical-pixel safe-area
  budget.
- Focus rings stay fully visible at every edge and are not clipped by scroll
  views.
- The smallest shipped metadata text remains legible at a 10-foot viewing
  distance.
- D-pad traversal has the same logical intent on every class even when the
  pixel layout changes.
- Opening transport controls, Mini Guide, Drawer, Guide, or a context menu does
  not reflow or interrupt live playback.

Capture a photo/screenshot of every edge case and a short focus-path trace.
Supporting screenshots alone are not a pass; the path must be driven on the
physical device with its real remote.

#### Scale and performance

- Rapid D-pad traversal does not visibly drop input.
- Browsing an authorized approximately 12,000-channel fixture has no visible
  jank or stall attributable to the UI.
- Capture available frame statistics/timings alongside the observation.
- Do not invent a numeric threshold where Issue 05 supplies none. A visibly
  dropped input or visible jank is a failure; preserve the trace for a focused
  performance issue.

#### Physical remote

Exercise on every device:

- D-pad directions and Select;
- Back;
- MENU or long-press Select;
- play/pause and other available media keys;
- channel up/down.

The final pass must use the real remote. If the supplied remote physically lacks
a named key, record `HARDWARE CAPABILITY GAP`; an ADB/keyboard substitute may
help diagnosis but cannot turn that row into a physical pass.

### PR #1177: Long-list picker

Run on every available matrix device:

1. Open Country, Language, and Category and confirm each uses the TV-native
   picker rather than the legacy dialog.
2. From an option group, press Left and confirm focus enters the A-Z jump rail.
3. Press Right and confirm focus returns to the prior item group and logical
   position.
4. Select a value, back out, and reopen the same picker; confirm the value
   appears under Recent.
5. Use a fixture with at least 500 entries and traverse/scroll/jump through the
   picker without visible stutter or lost input.
6. Confirm no Favourites UI appears. Its absence is intentional and must not be
   reported as a missing implementation.

A pass requires all three picker dimensions and both Left/Right focus
transitions to work from real D-pad input on every required device class.

### PR #1188: Wi-Fi Settings action

At minimum, execute on one real Fire TV class and one real Android/Google TV
class; run on all four matrix devices when possible:

1. Start from a known app state and record current playback/selection state.
2. Disconnect Wi-Fi until the offline banner appears.
3. Use the physical remote to select Wi-Fi Settings.
4. Confirm the OEM system Wi-Fi settings screen actually opens.
5. Reconnect as needed and press Back to return.
6. Confirm the app resumes without a crash, focus trap, or unintended loss of
   the previously recorded playback/selection state.

If `Settings.ACTION_WIFI_SETTINGS` is unsupported or routed incorrectly on an
OEM, mark the row failed and file one OEM-specific issue. Do not accept the
button click alone as evidence that system settings opened.

### PR #1190: QR phone-handoff onboarding

Run on every available matrix device with a real phone on the same Wi-Fi:

1. Start from the empty-playlist screen and select Scan with phone.
2. Confirm a readable QR code renders within the safe area.
3. Scan it with the phone and confirm the LAN form loads without a broken or
   unreachable page.
4. Submit an authorized playlist URL.
5. Confirm the TV receives it and pre-fills the existing Add Playlist sheet;
   it must not silently auto-import without TV confirmation.
6. Start a fresh QR session, leave it idle for more than five minutes, and
   confirm expiry plus the Generate new code recovery action.
7. Confirm no USB import option appears. This is an intentional omission, not
   a failure.

Never publish the QR token, pairing URL, submitted playlist URL, IP address, or
credentials in screenshots, logs, or issue comments.

### PR #1237: Sustained-stall failover

Run on every available matrix device with controlled, repeatable network
degradation:

1. Select a channel with a known primary plus backup/quality URL source.
2. Start primary playback and then throttle/degrade the network or primary CDN
   until continuous buffering lasts at least four seconds.
3. Confirm the player switches automatically to the backup without input.
4. Confirm playback resumes and the existing failover toast appears.
5. On a single-source channel, force the same sustained stall and confirm the
   normal error/retry state appears instead of a silent freeze.
6. Trigger a brief self-recovering rebuffer shorter than about four seconds and
   confirm playback resumes without a source switch.

Record the degradation method, observed stall duration, source count, whether a
switch occurred, recovery time, toast visibility, and final state. Do not
publish raw source URLs or credentials. If the network method cannot reliably
separate a transient rebuffer from a sustained stall, mark the result
inconclusive rather than guessing.

### Evidence layout

Create one dated campaign document when execution begins, for example:

`docs/release/evidence/airo-tv-physical-device-qa-YYYY-MM-DD.md`

Use these tables:

1. Device metadata, one row per required class.
2. Common Issue 05 checks, one result per device.
3. PR #1177 checks, one result per device.
4. PR #1188 checks, one result per applicable device.
5. PR #1190 checks, one result per device.
6. PR #1237 checks, one result per device.
7. Evidence gaps and linked defect issues.

Every result must be `PASS`, `FAIL`, `EVIDENCE GAP`, `HARDWARE CAPABILITY GAP`,
`INCONCLUSIVE`, or `NOT RUN`, followed by an observation and evidence link.
Generate the existing #589 D-pad report for each physical device where the
measured traversal data applies; use distinct output names so one device does
not overwrite another device’s evidence.

### Campaign pass gate

- All four required physical device classes are represented.
- Required metadata is factual and complete for every device.
- Every common Issue 05 row passes on every device.
- PR #1177, #1190, and #1237 rows pass on every device.
- PR #1188 passes on at least one Fire TV and one Android/Google TV OEM class,
  with gaps on other devices explicitly recorded.
- No physical-remote row is credited from keyboard, ADB, browser, or emulator
  input.
- Every failure or inconclusive behavior has a focused linked issue.
- Evidence is redacted and reviewed by TV Experience, Playback where relevant,
  Chief QA, Chief UX, and Release.

## Assignment A: #589 Fire TV D-pad Traversal

### Plain-language goal

Install the Airo TV build on a Fire TV, use only the Fire remote, and prove a
user can reach and operate the IPTV browse controls without losing focus,
seeing overflow, or becoming trapped.

### Preconditions

- Create a new issue worktree from the latest fetched `origin/main`.
- Record the commit, build mode, APK filename, APK SHA256, package ID
  `io.airo.app.tv`, device model, Android base version, and Fire OS build.
- Use `app/lib/main_tv.dart` and `--dart-define=APP_VARIANT=tv`.
- Use the physical remote for the acceptance pass. ADB key events may help
  diagnose a failure, but must not be presented as proof of physical-remote UX.
- Load only an authorized deterministic playlist/source.

### Manual route

1. Launch from the Fire TV Leanback/home tile.
2. Confirm an obvious initial focus target.
3. Reach and activate each required control class: Search, Playlist, Help,
   Refresh, a category tile, grid/list toggle, recent/all filter, and a channel
   card.
4. Open Help and dismiss it using only D-pad/Back.
5. Traverse at least eight channel cards in more than one direction.
6. Scroll far enough to prove focus remains visible and the grid/list can
   continue beyond the first screen.
7. Press Back from nested surfaces and confirm there is no trap or crash.
8. Watch the device screen and logs for lost focus, overflow, or render errors.

Count the actual required control classes before the run and use that same
number as both the denominator and, only if successful, the reachable count.
Do not invent a count to make the report pass.

### Pass condition

- Every required control class is reachable.
- At least eight channel cards are traversed.
- Help opens and dismisses.
- Focus-loss count is zero.
- Overflow count is zero.
- Render-error count is zero.

Generate the repository report with `melos run bench:tv-dpad-report`, using the
measured values. Attach the sanitized JSON/Markdown result to #589. Keep raw
device logs and screenshots in the approved evidence location, not pasted
unredacted into the issue.

### What this assignment does not close

#589 also names broader mobile/web regression and accessibility confidence.
Report the physical D-pad slice as complete and leave the issue open if those
other gates lack evidence.

## Assignment B: #459 Google Cast V1 Matrix

### Plain-language goal

Prove Airo can cast an IPTV HLS channel from both supported phone platforms to
a real Google Cast receiver and recover from common device/network changes.

### Preconditions

- Android sender with the tested Airo build.
- iPhone sender with the tested debug/TestFlight build.
- Chromecast-enabled TV, Google TV, Android TV with Cast, or Sony BRAVIA that
  appears in Google Cast discovery.
- All devices on the same Wi-Fi.
- Authorized public HLS channel and its stable channel ID.
- Exact app build, sender OS versions, receiver model, and receiver OS recorded.

### Manual route for each sender

1. Discover and select the receiver.
2. Start HLS playback and capture first visible playback.
3. Stop from the mini controller.
4. Cast again and disconnect the receiver during playback.
5. Move the sender off Wi-Fi, then restore Wi-Fi.
6. Background and return to the app while the receiver continues.
7. If exercising the #590 regression, switch A → B → C without reconnecting;
   use `melos run bench:cast-channel-switch-report` with measured values.

### Pass condition

- Receiver is discoverable from both Android and iOS.
- HLS playback starts on the receiver.
- Stop, disconnect, Wi-Fi loss/recovery, and background/return are recoverable
  and do not crash the sender.
- Evidence includes the required screenshots and metadata.
- Every defect becomes a separate issue linked to #459.

Fire TV with only Amazon Cast, MacBook AirPlay Receiver, browser receivers, and
local phone files are outside this assignment.

## Assignment C: #889 CV-033 Phone-Hosted File Streaming

### Plain-language goal

Prove a real Android phone can temporarily serve a large local movie over LAN
to a real Google Cast receiver, including seeks and lifecycle failures, without
copying the movie to the TV or exposing the session token.

### Preconditions

- Tested Android build contains the merged #1155, #1156, and #1157 fixes.
- At least 6 GB free on the phone.
- Real approximately 5 GB H.264/AAC MP4 on the phone.
- Deliberately unsupported file such as AVI or MPEG-2.
- Google Cast receiver advertising `_googlecast._tcp.local`.
- Laptop on the same LAN for `curl` security/socket checks.
- Router model and Wi-Fi band recorded.
- Baselines recorded: phone battery/thermal state and receiver storage.

### Run the issue’s matrix exactly

1. Cold handoff; first frame in under 10 seconds.
2. Seek to about 90%; resume in under 5 seconds at the correct position.
3. Seek to about 10%; same criterion.
4. Pause for 3 minutes and resume.
5. Play for 30 minutes; no more than one rebuffer per 10 minutes; record
   battery drain and thermal state.
6. Compare receiver storage before/after; growth remains under 50 MB of cache
   noise.
7. Select unsupported media; show the explicit unsupported state and start no
   session.
8. Stop casting; receiver stops and the server socket refuses a later request.
9. Wrong token returns 404; correct active URL returns 206. Never publish the
   real URL or token.
10. Drop Wi-Fi for 30 seconds and restore it; record exact behavior.
11. Swipe-kill Airo during playback; record receiver and server behavior.
12. Repeat items 1-3 on a second receiver only if it implements the same Google
    Cast protocol.

### Failure rule

Do not fix a product bug during dogfood. Stop only the affected case, preserve
sanitized evidence, file a focused follow-up issue, and continue with cases
that remain safe and meaningful. A failed or blocked row is not a passed
matrix, and merging partial evidence must not auto-close #889.

### Pass condition

- All executable rows have factual results and timings.
- Required positive-path rows pass on at least one supported receiver.
- Logs contain no full URL, token, local path, SSID, or BSSID.
- Evidence document is updated and reviewed.
- #889 receives a concise matrix summary and links to every follow-up defect.

## Assignment D: #683 Final Release Qualification

Do not begin this assignment until the release owner supplies:

- exact final artifact filename and SHA256 from the release manifest;
- package/profile being qualified;
- required physical or managed device classes;
- Fire TV support classification;
- permitted waivers, approver, and expiry;
- target release identifier.

Then install that exact artifact on each required class and record install,
launch, remote navigation/layout, and any profile-specific checks. Earlier
debug-build evidence from #589/#459/#889 may inform risk, but it cannot qualify
a different final artifact.

Produce the evidence JSON described in
`docs/release/V2_RELEASE_QUALIFICATION.md`, then run the public qualification
report/preflight. Public mode must fail if evidence or an approved waiver is
missing. Do not publish or trigger release CI unless the release owner
explicitly requests it.

## Assignment E: #1081 Launch Gate

This is not currently delegable as a hardware-only task. Before execution:

1. #889 must have a valid baseline pass.
2. #1076-#1080 plus #1091/#1092 must provide the Airo-native receiver
   foundation and compatibility planning.
3. Product/QA must name the supported low-end device matrix and clarify whether
   one device class or every Android TV/Google TV/Fire TV class is required.
4. Diagnostics schema, redaction assertions, feature flag, recovery/install
   guidance, and rollout metrics must exist and be testable.

Only then should an associate receive a per-device qualification checklist.
Until then, keep #1081 blocked and do not use CV-033 Google Cast evidence as an
Airo-native receiver launch approval.

## Evidence and Privacy Rules for Every Campaign

- Record exact build commit, artifact filename, artifact SHA256, package ID,
  device model, OS version, date, and result.
- Record router model and band when the issue asks for network conditions.
- Use stable public profile labels instead of serial numbers, receiver IDs,
  LAN IPs, SSIDs, or BSSIDs.
- Never paste raw playlist URLs with credentials, media paths, full local
  server URLs, session tokens, or unredacted logcat into GitHub.
- Store visual evidence in the repository-approved evidence path and link it.
- Mark each row `PASS`, `FAIL`, `BLOCKED`, or `NOT RUN`; never convert missing
  evidence into a pass.
- File one focused issue per defect and link the parent hardware issue.
- Do not change code during a qualification run. A fix gets its own issue,
  worktree, owner, tests, and later rerun.
- Do not close a parent or tracker because a partial evidence PR merged.

## Completion Checkpoints

### Checkpoint 1: Assignment readiness

- Correct protocol and hardware matched to the issue.
- Latest `origin/main` fetched and issue worktree verified.
- Required fixtures and exact build metadata available.
- Issue owner and evidence location confirmed.

### Checkpoint 2: Individual campaign

- Every matrix row has an explicit result and observation.
- Generated report reflects measured values.
- Sensitive values are redacted.
- Failures have linked follow-up issues.

### Checkpoint 3: Issue closure

- The issue’s full acceptance criteria, not only the hardware slice, are met.
- Evidence is committed/attached in the required location.
- Required owner/reviewer sign-off is present.
- Tracker issues are updated only from completed child evidence.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Fire TV is incorrectly used as #889/#459 receiver | Invalid Cast evidence | Confirm `_googlecast._tcp.local`; classify Amazon Cast-only Fire TV as incompatible. |
| Debug evidence is reused for a release artifact | False release qualification | #683 must name and hash the exact final artifact. |
| Tester fixes code mid-run | Evidence becomes non-reproducible | File a separate bug, finish safe rows, rerun later from a reviewed build. |
| Sensitive LAN/media data reaches GitHub | Security/privacy incident | Use sanitized report tools and scan logs/screenshots before attachment. |
| Partial evidence closes a parent automatically | Acceptance criteria remain unproven | Reopen/restore state and state explicitly which rows remain. |
| Hardware is unavailable | Campaign stalls | Mark the exact prerequisite `BLOCKED`; do not substitute protocol-incompatible hardware. |

## Open Decisions Requiring Maintainer or Release Owner

- #683: final required device inventory, Fire TV classification, waiver
  authority, and final artifact.
- #1081: exact low-end device-class coverage required for the launch matrix.
- #459: whether an iPhone/TestFlight build and iOS tester are currently
  available for the required iOS sender pass.
