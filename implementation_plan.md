# Qualification of Airo TV v0.0.5 for Sony BRAVIA 2 (Entry‑Level Google TV)

**Goal**: Deliver a fully automated integration‑test suite that validates Airo TV on a low‑end TV profile (MediaTek‑based, 2 GB RAM, 60 Hz) without requiring physical hardware. The suite will:
- Drive the UI via D‑Pad simulation.
- Import a curated IPTV playlist (including Vevo Pop) from the iptv‑org M3U/EPG sources.
- Verify playback of an HLS stream, codec fallback, and stability under a 30‑minute soak.
- Enforce performance budgets (FPS ≥ 55, frame jank ≤ 32 ms, RSS ≤ 200 MB, image‑cache ≤ 30 MB).
- Produce screenshots and a concise CSV report for CI consumption.

---
## User Review Required
> [!IMPORTANT]
> The implementation will **write files** under `app/integration_test/tv/` and add dependencies (`video_player`, `connectivity_plus`). Please confirm that these additions are acceptable.

---
## Open Questions
> [!WARNING]
> 1. **Preferred video player library** – The existing app uses a custom `AiroVideoPlayer`. Should we switch to `video_player` for the test harness, or mock the existing player?
> 2. **Channel list size** – We plan to use a 10‑channel fixture (including Vevo Pop). Is this sufficient, or do you want a larger set for stress testing?
> 3. **Soak test duration** – Currently set to 30 min. Do you need a longer run (e.g., 60 min) for certification?
> 4. **Reporting format** – CSV is preferred, but would you like an HTML summary with embedded screenshots?

---
## Proposed Changes
### Helpers (already added)
- `helpers/performance_monitor.dart` – FPS, RSS, image‑cache checks.
- `helpers/tv_screen_robot.dart` – D‑Pad navigation, channel selection, playback verification, screenshot capture.
- `helpers/network_simulator.dart` – Bandwidth, latency, packet‑loss simulation.
- `helpers/playlist_fixtures.dart` – M3U playlist with Vevo Pop and dummy channels (already present).

### New Test Files
#### [NEW] `test/live_playback_test.dart`
- Boots the app via `TvTestHarness`.
- Applies a low‑end device profile (`DeviceClass.tvLow`).
- Uses `NetworkSimulator` to emulate a 5 Mbps/2 % loss network.
- Drives UI to **Live** screen, imports playlist, selects **Vevo Pop**.
- Starts `PerformanceMonitor` before playback, asserts FPS, RSS, cache.
- Runs a 30‑minute soak using `await Future.delayed(Duration(minutes: 30))` while continuously sampling performance.
- Captures a screenshot every 5 minutes for visual audit.
- Writes results to `test_report.csv`.

#### [NEW] `test/navigation_focus_test.dart`
- Validates **focus trap** across all top‑level routes.
- Exercises Back‑button behavior, D‑Pad navigation loops, and on‑screen keyboard invocation.
- Uses `FocusAssertions` helper (existing) to dump focus tree and ensure no orphan nodes.

#### [NEW] `test/epg_import_test.dart`
- Downloads the EPG XML from `https://github.com/iptv-org/epg` (mocked via local fixture).
- Verifies that the guide view correctly parses program metadata for Vevo Pop.
- Checks that the UI updates after a simulated time‑zone shift.

### CI Integration
- Add a new `flutter test --tags=tv_integration` script in `tool/run_tv_tests.sh`.
- Ensure the script sets `FLUTTER_TEST=1` and caps memory usage.

---
## Verification Plan
### Automated Tests
- Run `flutter test integration_test/tv/live_playback_test.dart` and `navigation_focus_test.dart` locally on macOS.
- Verify that the CSV report contains columns: `timestamp, fps, avgFrameMs, maxFrameMs, rssMb, imageCacheMb, jankCount`.
- Ensure no test exceeds the defined performance thresholds.

### Manual Verification (optional)
- After CI pass, a reviewer can open the generated screenshots and CSV to confirm visual fidelity and performance stability.

---
*This plan assumes the existing helper files are in place. If you approve, I will generate the new test files and CI script.*
