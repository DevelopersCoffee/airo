# Milestone 2 — Pixel 9 Qualification Evidence

- Date: 2026-07-29
- Branch: `codex/milestone-2-reliability-20260728`
- Source commit before evidence update:
  `c73748adef1565dd1ec9296377a3e3a50c6f6d3f`
- Device: Google Pixel 9 (`tokay`)
- OS: Android 17 / API 37
- Build:
  `google/tokay/tokay:17/CP2A.260705.006/15641320:user/release-keys`
- Package: `io.airo.app`, debug, version code 7, target SDK 36
- Normal APK SHA-256:
  `db33ca42dc74cd891ed0cc963c95eb53431924018b0b118c2fcf392ddfaec6a0`
- Normal APK size: 243,704,774 bytes

The APK was installed with `adb install -r`. The app was never uninstalled and
its data was never cleared. Android retained the original first-install time
of 2026-07-26 20:14:28 and the existing databases, preferences, and cached
files remained present.

## App lifecycle and resource snapshot

| Check | Result | Decision |
| --- | --- | --- |
| Cold launch | `TotalTime=2725 ms`, `WaitTime=2729 ms` | Captured; no release budget is defined |
| Warm delivery | `TotalTime=0 ms`, `WaitTime=8 ms` | Passed |
| Steady debug memory | PSS 567,259 KB; RSS 652,920 KB; swap PSS 31,724 KB | High; investigate with a profile build |
| Idle CPU point sample | 0.0% app CPU | Captured; not an active-workload benchmark |
| App sandbox before replace-in-place | 2,669,293 KB | Baseline |
| App sandbox after normal APK restoration and model cleanup | 2,628,931 KB | No test-model residue |
| Reboot | Device reboot command accepted | Post-boot audit blocked when wireless ADB did not re-advertise |

The installed app exposed no durable `io.airo.app` JobScheduler evidence before
the reboot. A post-reboot audit is still required after wireless debugging is
available again; this run does not prove kill/reboot recovery for #518.

## UI and accessibility

| Check | Result | Decision |
| --- | --- | --- |
| Portrait at the user's 1.15 font scale | Rendered and semantics tree available | Passed |
| Forced landscape | Rendered and exposed adaptive eight-destination navigation | Passed with overlap observation |
| System dark mode | App remained readable | Passed |
| 200% font scale | Heading clipped, `Budget remaining` truncated, and floating action overlapped content | Failed |
| Keyboard handling | ADB tap on the enabled quick-add field did not show the IME | Unverified / failed interaction |
| Semantics | Named navigation, notification, settings, cards, and actions were present | Partial; two icon buttons were `NAF`/unnamed |
| Split screen | Not completed | Open |
| Foldable/tablet | Not applicable to Pixel 9 hardware | Requires separate target |

The reversible settings were restored exactly after the run:

- font scale `1.15`
- accelerometer rotation `0`
- user rotation `0`
- night mode `no`
- airplane mode `0`

## Physical MediaPipe text embedding

The test-only converted
`sentence-transformers/all-MiniLM-L6-v2` artifact was copied to the debuggable
app sandbox for this run only.

- Model size: 89,970,492 bytes
- Model SHA-256:
  `f1c6526c0d31cb222f179e1897e6d64d5e9617053261f1345f8536a4eb92b870`
- Dimensions: 384

| Check | Result | Decision |
| --- | --- | --- |
| Model integrity on device | SHA-256 matched | Passed |
| Provider cold open | 5,883 ms | Captured; slow |
| First embedding | 384 values, norm 1.000000213, 576 ms | Failed the 150 ms target |
| Repeat embedding | 384 values, norm 1.000000213, 522 ms | Failed the 150 ms target |
| Different embedding | 384 values, norm 0.999999891, 543 ms | Failed the 150 ms target |
| Repeat determinism | cosine 1.000000000 | Passed |
| Loaded-process memory | PSS 414,805 KB; RSS 511,224 KB; swap PSS 4,495 KB | Captured |
| Provider close | next call returned `provider_closed` | Passed |
| Fully disconnected offline run | Not proven | Airplane mode retained Wi-Fi for wireless ADB |

No embedding values or fixture text were emitted to the qualification log.
The run proves the real ARM64 Android provider path, integrity check,
dimensionality, normalization, determinism, and cleanup on Pixel 9. It does not
meet the latency target or replace a network-disconnected packet-capture run.

Cleanup was verified:

- provider closed;
- sandbox model removed;
- `/data/local/tmp` staging model removed;
- normal APK restored replace-in-place;
- app settings restored;
- no test artifact was added to source control or a release bundle.

## Local qualification matrix

Passed:

- release manifest generator tests;
- release qualification report generator tests;
- merge-readiness checker tests;
- all 89 `core_release` tests;
- build-profile, bundled-artifact, module-manifest, module-size, and
  worker-offload policy checks;
- app, `feature_meeting_intelligence`, and `platform_text_embeddings`
  analyzers;
- 7 embedding provider tests;
- 17 meeting feature tests;
- 22 focused app meeting/storage tests;
- 9 background download contract tests;
- 21 worker executor/scheduler tests;
- 10 orchestration storage tests;
- 32 focused database, audio-session, notification, deep-link, and LiteRT app
  tests.

The broad `core_ai` suite reached 275 tests with one load failure:
`test/litert/litert_lm_runtime_adapter_test.dart` cannot construct
`_FakeModelDownloadService` because `ModelDownloadService` has no unnamed
constructor. The qualification run did not modify unrelated code to mask this
failure.

## Remaining acceptance boundaries

- #510: host download contract passes; physical cancel/resume/retry/network/
  reboot/storage queue matrix remains.
- #511–#512: no real Whisper or diarization provider/fixtures are available.
- #513: contract tests pass, but real local LLM load, overflow, cancellation,
  long-meeting, memory-pressure, and battery tests remain.
- #514: real playback seek/speed/background/headphone/Bluetooth/call tests
  require a media fixture and peripherals.
- #515: scheduling/deep-link contracts pass; real progress/completion/failure
  notifications remain.
- #516: temporary-database recovery, corruption, backup/restore, and large
  history tests pass; destructive testing of the user's database was not
  performed.
- #518: the current meeting background handle is in-process; durable
  kill/reboot recovery remains unproven.
- #519: 200% text is a confirmed failure; split-screen and separate
  foldable/tablet targets remain.
- #520: physical startup, memory, storage, and embedding metrics are captured;
  latency failed and battery/GPU/NPU/long-run profiling remains.
