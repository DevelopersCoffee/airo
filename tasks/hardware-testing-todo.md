# Hardware Testing Delegation Checklist

This checklist is for future execution. No item below was run while preparing
the plan.

## Task 1: Prepare one issue-specific campaign

**Description:** Create a clean, reproducible QA workspace for exactly one
hardware issue.

**Acceptance criteria:**

- [ ] Run `git fetch origin main v1_bkp`.
- [ ] Create a new issue branch/worktree from the latest `origin/main`.
- [ ] Verify `HEAD`, `origin/main`, and their merge-base match before any work.
- [ ] Record issue number, owner, device inventory, fixture inventory, build
      commit, artifact filename/SHA256, and evidence destination.
- [ ] Confirm the issue’s protocol matches the available hardware.

**Verification:**

- [ ] `git status --short --branch` shows the intended clean issue worktree.
- [ ] `git rev-parse HEAD`, `git rev-parse origin/main`, and
      `git merge-base HEAD origin/main` show the intended base.
- [ ] The issue comment/working note states “QA/evidence only; bugs are filed
      separately.”

**Dependencies:** None.

**Files likely touched:** Evidence documents only.

**Estimated scope:** Small.

## Task 2A: Execute the expanded Airo TV physical device matrix

**Description:** Qualify the Issue 05 scaling/overscan contract and physically
verify merged PRs #1177, #1188, #1190, and #1237 on the four required TV
classes. This task includes the #589 physical D-pad slice.

**Acceptance criteria:**

- [ ] Test a Fire TV Stick Lite/equivalent constrained device at 720p.
- [ ] Test a Fire TV Stick 4K configured for 1080p output.
- [ ] Test a Google/Android TV at 4K output.
- [ ] Test an Android TV box reporting approximately 1920×1080 logical pixels
      at DPR/density 1.
- [ ] For each device, record OS/build, model, output mode, logical size, DPR,
      safe insets, text scale, Airo build SHA, artifact filename/SHA256,
      package/build mode, remote type, date, and tester.
- [ ] Mark any unavailable class `EVIDENCE GAP`; do not substitute an
      emulator/browser or different device class.
- [ ] Use the real physical remote for final input evidence.

**Common Issue 05 verification on every device:**

- [ ] No actionable content crosses the 32×24 logical-pixel safe-area budget.
- [ ] Edge focus rings remain fully visible and unclipped.
- [ ] Minimum metadata text is legible from 10 feet.
- [ ] D-pad traversal follows the same logical intent across device classes.
- [ ] Transport, Mini Guide, Drawer, Guide, and context menu overlays do not
      reflow or interrupt live playback.
- [ ] Rapid D-pad input and an authorized approximately 12,000-channel library
      show no visible jank or dropped input; available frame timings are saved.
- [ ] Back, MENU/long-press Select, media keys, and channel up/down are tried
      with each physical remote; missing physical keys are capability gaps,
      not simulated passes.

**PR #1177 verification on every device:**

- [ ] Country, Language, and Category use the TV-native long-list picker.
- [ ] Left enters the A-Z rail and Right returns to the prior item group.
- [ ] A selected value appears under Recent after close/reopen.
- [ ] A 500+ entry picker scrolls/jumps without visible stutter.
- [ ] No Favourites UI is shown, as intentionally designed.

**PR #1188 verification:**

- [ ] On at least one Fire TV and one Android/Google TV, disconnect Wi-Fi,
      select Wi-Fi Settings with the remote, and confirm the OEM system screen
      opens.
- [ ] Back returns cleanly to the app without crash, focus trap, or unintended
      playback/selection-state loss.

**PR #1190 verification on every device:**

- [ ] Scan with phone renders a readable QR code.
- [ ] A real same-LAN phone opens the form.
- [ ] Submitted authorized playlist URL pre-fills the Add Playlist sheet.
- [ ] A session idle for more than five minutes expires and offers Generate
      new code.
- [ ] No USB import option appears, as intentionally designed.

**PR #1237 verification on every device:**

- [ ] A sustained stall of at least four seconds on a multi-source channel
      automatically switches to a backup and resumes.
- [ ] The existing failover toast appears during the automatic switch.
- [ ] A sustained stall on a single-source channel reaches the normal
      error/retry screen rather than silently freezing.
- [ ] A brief self-recovering rebuffer under about four seconds does not switch
      source.
- [ ] Degradation method, measured duration, recovery time, source count, toast,
      and final state are recorded without raw source URLs.

**Verification:**

- [ ] Create a dated
      `docs/release/evidence/airo-tv-physical-device-qa-YYYY-MM-DD.md`.
- [ ] Use only `PASS`, `FAIL`, `EVIDENCE GAP`, `HARDWARE CAPABILITY GAP`,
      `INCONCLUSIVE`, or `NOT RUN` for matrix results.
- [ ] Generate a distinct sanitized D-pad report per physical device; do not
      overwrite one device’s artifact with another.
- [ ] Link each failure/inconclusive row to a focused issue.
- [ ] Report overall `PASS` only when all required classes and mandatory rows
      pass.

**Dependencies:** Task 1; all four device classes; physical remotes; authorized
12k-channel and 500+ picker fixtures; real phone; repeatable network degradation
method; channels with multi-source and single-source cases.

**Files likely touched:**

- `docs/release/evidence/airo-tv-physical-device-qa-YYYY-MM-DD.md`
- approved redacted visual/trace evidence
- per-device D-pad JSON/Markdown reports

**Estimated scope:** Large campaign. Do not execute it as one task. Use the
focused device slices below with one shared evidence schema and final QA owner.

### Task 2A.1: Fire TV constrained 720p slice

- [ ] Complete every common, #1177, #1190, and #1237 row on the Fire TV Stick
      Lite/equivalent at 720p.
- [ ] Complete #1188 on this Fire TV OEM.
- [ ] Save metadata, measured results, and redacted evidence without making
      claims for any other matrix class.

**Dependencies:** Task 2A campaign prerequisites.

**Estimated scope:** Medium.

### Task 2A.2: Fire TV 4K-at-1080p slice

- [ ] Confirm the Fire TV Stick 4K is actually configured for 1080p output.
- [ ] Complete every common, #1177, #1190, and #1237 row.
- [ ] Complete #1188 and save this device’s distinct metadata/evidence.

**Dependencies:** Task 2A campaign prerequisites.

**Estimated scope:** Medium.

### Task 2A.3: Google/Android TV 4K slice

- [ ] Confirm the physical Google/Android TV is actually outputting 4K.
- [ ] Complete every common, #1177, #1190, and #1237 row.
- [ ] Complete the required Android/Google TV #1188 OEM check and save distinct
      metadata/evidence.

**Dependencies:** Task 2A campaign prerequisites.

**Estimated scope:** Medium.

### Task 2A.4: Android TV DPR-1 1080p slice

- [ ] Confirm diagnostics report approximately 1920×1080 logical pixels and
      DPR/density 1; do not infer this from output mode.
- [ ] Complete every common, #1177, #1190, and #1237 row.
- [ ] Run #1188 when supported and save distinct metadata/evidence.

**Dependencies:** Task 2A campaign prerequisites.

**Estimated scope:** Medium.

### Task 2A.5: Consolidate and review the campaign

- [ ] Combine the four device slices without overwriting per-device artifacts.
- [ ] Mark overall status from factual rows: Pass only with all hardware and
      mandatory checks; otherwise Failed or Incomplete.
- [ ] Link failures/inconclusive rows and route review to the owning agents.

**Dependencies:** Tasks 2A.1-2A.4.

**Estimated scope:** Small.

## Checkpoint: Expanded physical matrix

- [ ] PR merge SHAs are ancestors of the tested build.
- [ ] Physical evidence is distinct from browser/emulator supporting evidence.
- [ ] Missing hardware prevents an overall Pass.
- [ ] #589 receives links to its applicable D-pad evidence without claiming its
      non-device gates are complete.
- [ ] #683 reuses the evidence only if the exact final release artifact matches.

## Task 2: Execute #589 on Fire TV or Android TV

**Description:** Prove the physical D-pad navigation slice independently of
Cast or local-file streaming.

**Acceptance criteria:**

- [ ] Launch `io.airo.app.tv` from the TV home/Leanback tile.
- [ ] Reach all inventoried controls using the physical remote.
- [ ] Traverse at least eight channel cards and prove scrolling retains focus.
- [ ] Open and dismiss Help using D-pad/Back.
- [ ] Record zero focus losses, overflows, and render errors for a pass.
- [ ] Record exact device/build metadata and every failure.

**Verification:**

- [ ] Generate the measured report with
      `melos run bench:tv-dpad-report`.
- [ ] Review the generated JSON and Markdown for truthful counts and redaction.
- [ ] Comment on #589 with the physical-slice result and remaining non-device
      closure gates.

**Dependencies:** Task 1; Fire TV or Android TV and physical remote.

**Files likely touched:**

- `artifacts/performance/airo-tv-dpad-traversal-report.json`
- `artifacts/performance/airo-tv-dpad-traversal-report.md`
- approved device evidence document

**Estimated scope:** Medium.

## Checkpoint: Fire TV assignment

- [ ] If Task 2A was completed, Task 2 was not redundantly rerun; its applicable
      evidence was linked instead.
- [ ] Fire TV was used for installed-app/remote testing, not misreported as a
      Google Cast receiver.
- [ ] Failures have separate linked issues.
- [ ] #589 remains open if broader regression/accessibility gates remain.

## Task 3: Execute #459 Google Cast V1 QA

**Description:** Run the IPTV HLS Cast matrix from Android and iOS senders to a
real Google Cast receiver.

**Acceptance criteria:**

- [ ] Android discovery and HLS playback pass.
- [ ] iOS local-network permission, discovery, and HLS playback pass.
- [ ] Stop, receiver disconnect, sender Wi-Fi loss/recovery, and
      background/return cases are recorded.
- [ ] Build numbers, sender OS versions, receiver model/OS, channel ID, and
      required screenshots are attached.
- [ ] Each defect is linked back to #459.

**Verification:**

- [ ] Receiver advertises/appears through Google Cast; Amazon Cast-only Fire TV
      and AirPlay-only Mac are excluded.
- [ ] If A → B → C switching is rerun, generate
      `melos run bench:cast-channel-switch-report` from measured values.
- [ ] #459 contains a complete matrix summary, or clearly says which sender
      platform remains blocked.

**Dependencies:** Task 1; Android sender, iPhone sender, Google Cast receiver,
authorized HLS source.

**Files likely touched:**

- approved Cast V1 evidence document
- optional `artifacts/performance/cast-channel-switch-report.json`
- optional `artifacts/performance/cast-channel-switch-report.md`

**Estimated scope:** Medium.

## Task 4: Rerun #889 CV-033 dogfood

**Description:** Execute the 12-item phone-hosted large-file matrix on a
protocol-compatible Google Cast receiver.

**Acceptance criteria:**

- [ ] Tested build contains closed fixes #1155, #1156, and #1157.
- [ ] Real ~5 GB H.264/AAC MP4 and unsupported media fixture are available.
- [ ] Items 1-12 have explicit results and timings.
- [ ] First frame, forward/back seeks, pause/resume, 30-minute playback,
      storage, unsupported format, stop/socket close, token check, Wi-Fi loss,
      and background-kill observations are recorded.
- [ ] Logs contain no full URL, token, file path, SSID, or BSSID.
- [ ] Each failure has a separate linked issue.

**Verification:**

- [ ] Update `docs/release/evidence/cv-033-device-dogfood.md`.
- [ ] Review evidence against every row in #889.
- [ ] Post a sanitized matrix summary to #889.
- [ ] Do not close #889 when any required positive-path row is failed, blocked,
      not run, or supported only by partial evidence.

**Dependencies:** Task 1; Android phone, Google Cast receiver, laptop, required
media fixtures, shared Wi-Fi.

**Files likely touched:**

- `docs/release/evidence/cv-033-device-dogfood.md`
- approved screenshot/photo assets

**Estimated scope:** Medium.

## Checkpoint: Cast campaigns

- [ ] #459 used IPTV HLS and both supported sender platforms.
- [ ] #889 used a phone-local large file and tested LAN server behavior.
- [ ] Neither campaign used Amazon Cast-only Fire TV as a Google Cast receiver.
- [ ] Evidence and conclusions were kept separate.

## Task 5: Execute #683 for the final release artifact

**Description:** Qualify the exact artifact selected by the release owner, or
record an approved waiver for each missing required class.

**Acceptance criteria:**

- [ ] Release owner supplies the final manifest/artifact, SHA256, target
      release, required device list, Fire TV status, and waiver policy.
- [ ] Exact artifact is installed and tested on each required physical/managed
      device class.
- [ ] Evidence JSON contains profile, filename, model, OS, check type, and
      result.
- [ ] Every waiver contains reason, approver, and expiry.

**Verification:**

- [ ] Generate the report using
      `scripts/generate-release-qualification-report.py --mode public`.
- [ ] Run `melos run release:qualification-preflight` in public mode.
- [ ] Public mode passes only with complete evidence or valid waivers.
- [ ] Attach the report to the release summary/artifacts as directed by the
      release owner.

**Dependencies:** Task 1; release-owner decisions and final artifact. Earlier
debug hardware passes are context, not a substitute.

**Files likely touched:**

- release qualification evidence JSON
- generated `Release-Qualification-Report.md`
- `artifacts/release/release-qualification-preflight.json`
- `artifacts/release/release-qualification-preflight.md`

**Estimated scope:** Medium.

## Task 6: Defer #1081 until the receiver foundation is ready

**Description:** Keep the milestone-10 launch gate blocked until its software
and hardware prerequisites exist.

**Acceptance criteria:**

- [ ] #889 has passing baseline evidence.
- [ ] #1076-#1080 and #1091/#1092 prerequisites are complete.
- [ ] Maintainer clarifies the required Android TV/Google TV/Fire TV device
      coverage.
- [ ] Diagnostics redaction, install/recovery guidance, experimental flag, and
      rollout metrics are testable.
- [ ] A new per-device qualification checklist is approved before execution.

**Verification:**

- [ ] #1081 is not represented as passed by CV-033 Google Cast evidence alone.
- [ ] #1084 changes only after authoritative child-issue evidence exists.

**Dependencies:** #889, #1076-#1080, #1091, #1092, and maintainer decisions.

**Files likely touched:** None until prerequisites are satisfied.

**Estimated scope:** Blocked; reassess later.

## Final Review

- [ ] Every issue has the correct device/protocol pairing.
- [ ] Every task has explicit acceptance evidence.
- [ ] No missing or partial row is described as passed.
- [ ] No raw secret, token, media path, credentialed URL, device serial, or LAN
      identifier is published.
- [ ] Code fixes, publishing, CI release builds, and issue closure happen only
      under their own authorization and policy gates.
