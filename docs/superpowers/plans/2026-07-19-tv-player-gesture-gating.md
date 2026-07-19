# TV Player Touch-Gesture Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove touch-only affordances (brightness/volume swipe gestures, lock button, swipe-channel-change buttons) from `VideoPlayerWidget` when it renders inside the Android TV/Fire TV shell, since a remote control cannot trigger touch drags or taps on invisible overlay zones.

**Architecture:** `VideoPlayerWidget` currently renders `PlayerGestureOverlay` (brightness/volume drag) and `PlayerLockButton` unconditionally, regardless of caller. Add a single `enableTouchGestures` constructor param (default `true`, preserving current mobile/desktop behavior) that gates both. `iptv_tv_screen.dart`'s two `VideoPlayerWidget` call sites pass `enableTouchGestures: false`. The same fullscreen call site's `enableSwipeChannelChange: true` is also flipped to `false` — those prev/next `IconButton`s are gated by that flag already and are unreachable via d-pad (not wrapped in `TvFocusable`), so leaving them enabled just draws dead touch targets over the TV player.

**Tech Stack:** Flutter/Dart, flutter_riverpod, flutter_test.

## Global Constraints

- Do not change `VideoPlayerWidget`'s default parameter values — mobile/desktop callers (`iptv_screen.dart`) must keep identical behavior with zero call-site changes.
- `enableTouchGestures` gates exactly: `PlayerGestureOverlay` (brightness/volume drag surface) and `PlayerLockButton`. It does not gate `enableSwipeChannelChange`'s prev/next buttons — that stays a separate, already-existing flag.
- Package under test: `packages/feature_iptv`. Run tests with `flutter test` from that directory (or `melos`/workspace runner if the repo uses one — check `packages/feature_iptv/pubspec.yaml` for a test script before assuming plain `flutter test` works).

---

### Task 1: Add `enableTouchGestures` gate to `VideoPlayerWidget`

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart:23-37` (constructor), `:337-345` (`PlayerGestureOverlay` wrap), `:480-490` (`PlayerLockButton` position)
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart`

**Interfaces:**
- Produces: `VideoPlayerWidget({..., bool enableTouchGestures = true})` — new named param, default `true`.
- Consumes: nothing new; wraps existing `PlayerGestureOverlay` and `PlayerLockButton` widgets already imported in this file.

- [ ] **Step 1: Write the failing test**

Add to `packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart` (append near the other gesture tests, after the existing `pumpPlayer` helper — extend the helper to accept the new flag rather than duplicating it):

```dart
  // Extend pumpPlayer's signature (see Step 1b below) then:

  testWidgets(
    'enableTouchGestures: false hides the lock button and brightness/volume gesture surface',
    (tester) async {
      await pumpPlayer(tester, enableTouchGestures: false);

      expect(find.byKey(const ValueKey('iptv-player-lock-button')), findsNothing);
      expect(find.byType(PlayerGestureOverlay), findsNothing);
    },
  );

  testWidgets(
    'enableTouchGestures defaults to true, preserving lock button and gesture surface',
    (tester) async {
      await pumpPlayer(tester);

      expect(find.byKey(const ValueKey('iptv-player-lock-button')), findsOneWidget);
      expect(find.byType(PlayerGestureOverlay), findsOneWidget);
    },
  );
```

Add the import needed for `PlayerGestureOverlay` at the top of the test file:

```dart
import 'package:feature_iptv/presentation/widgets/player_gesture_overlay.dart';
```

Update the `pumpPlayer` helper (top of `main()`) to thread the new flag through:

```dart
  Future<void> pumpPlayer(
    WidgetTester tester, {
    bool enableSwipeChannelChange = false,
    bool enableTouchGestures = true,
    PlayerBrightnessController? brightnessController,
    StreamingState? state,
    List<IPTVChannel>? channels,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (channels != null)
            iptvChannelsProvider.overrideWith((ref) async => channels),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              state ??
                  StreamingState(
                    playbackState: PlaybackState.idle,
                    isLiveStream: true,
                    currentChannel: const IPTVChannel(
                      id: 'news-1',
                      name: 'City News Live',
                      streamUrl: 'https://example.com/news.m3u8',
                      group: 'News',
                      category: ChannelCategory.news,
                    ),
                  ),
            ),
          ),
        ],
        child: MaterialApp(
          home: VideoPlayerWidget(
            enableSwipeChannelChange: enableSwipeChannelChange,
            enableTouchGestures: enableTouchGestures,
            brightnessController: brightnessController,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/video_player_widget_test.dart -N "enableTouchGestures"`
Expected: FAIL — `enableTouchGestures` is not a defined named parameter on `VideoPlayerWidget` (compile error), or (once compiling) the lock button / gesture overlay are still found because the gate doesn't exist yet.

- [ ] **Step 3: Implement the gate**

In `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart`, update the constructor (currently lines 23-37):

```dart
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final bool showControls;
  final VoidCallback? onFullscreenToggle;
  final bool enableSwipeChannelChange;
  final bool initiallyFullscreen;
  final bool enableTouchGestures;
  final PlayerBrightnessController? brightnessController;

  const VideoPlayerWidget({
    super.key,
    this.showControls = true,
    this.onFullscreenToggle,
    this.enableSwipeChannelChange = false,
    this.initiallyFullscreen = false,
    this.enableTouchGestures = true,
    this.brightnessController,
  });
```

Wrap the `PlayerGestureOverlay` (currently ~line 337) — replace the unconditional `PlayerGestureOverlay(...)` with a conditional that falls back to rendering its `child` directly when gestures are disabled:

```dart
                  widget.enableTouchGestures
                      ? PlayerGestureOverlay(
                          locked: _isLocked,
                          brightness: _brightness,
                          volume: state.isMuted ? 0.0 : state.volume,
                          onBrightnessChanged: _onBrightnessGestureChanged,
                          onVolumeChanged: (value) {
                            if (state.isMuted) service.toggleMute();
                            service.setVolume(value);
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Video display (engine-driven view surface).
                              if (videoView != null)
                                SizedBox.expand(
                                  child: FittedBox(
                                    fit: _boxFitFor(aspectRatioFit),
                                    child: videoView,
                                  ),
                                )
                              else if (state.playbackState == PlaybackState.loading)
                                _buildLoading()
                              else if (state.hasError && state.diagnostic != null)
                                _buildDiagnosticError(state)
                              else
                                _buildPlaceholder(state),

                              // Cinema mode vignette overlay
                              if (_isCinemaMode)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          center: Alignment.center,
                                          radius: 1.15,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.6),
                                          ],
                                          stops: const [0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Buffering indicator
                              if (state.isBuffering)
                                Container(
                                  color: Colors.black45,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            if (videoView != null)
                              SizedBox.expand(
                                child: FittedBox(
                                  fit: _boxFitFor(aspectRatioFit),
                                  child: videoView,
                                ),
                              )
                            else if (state.playbackState == PlaybackState.loading)
                              _buildLoading()
                            else if (state.hasError && state.diagnostic != null)
                              _buildDiagnosticError(state)
                            else
                              _buildPlaceholder(state),
                            if (_isCinemaMode)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment.center,
                                        radius: 1.15,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.6),
                                        ],
                                        stops: const [0.6, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (state.isBuffering)
                              Container(
                                color: Colors.black45,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
```

Wrap the `PlayerLockButton` block (currently ~lines 480-490) with the same flag:

```dart
                  // Lock button: touch-only concept, hidden entirely when
                  // enableTouchGestures is false (e.g. TV/remote input).
                  if (widget.enableTouchGestures)
                    Positioned(
                      top: 8,
                      right: 56,
                      child: AnimatedOpacity(
                        opacity: (_isLocked || _showControlsOverlay) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: PlayerLockButton(
                            key: const ValueKey('iptv-player-lock-button'),
                            locked: _isLocked,
                            onToggle: _toggleLocked,
                          ),
                        ),
                      ),
                    ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/video_player_widget_test.dart`
Expected: PASS — all tests in the file, including the two new ones.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart
git commit -m "feat(feature_iptv): gate touch-only player affordances behind enableTouchGestures"
```

---

### Task 2: TV screen opts out of touch gestures and swipe-channel buttons

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart` (compact card `VideoPlayerWidget` call, currently ~line 1076; fullscreen `VideoPlayerWidget` call, currently ~line 1209)
- Test: `packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart`

**Interfaces:**
- Consumes: `VideoPlayerWidget.enableTouchGestures` from Task 1.

- [ ] **Step 1: Write the failing test**

Add to `packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart` (check the file's existing setup/pump helper first and reuse it — do not duplicate provider wiring; the exact helper name isn't fixed here because it must match whatever fixture the file already uses):

```dart
  testWidgets(
    'TV fullscreen player disables touch gestures and swipe-channel buttons',
    (tester) async {
      // ... pump the TV screen via the file's existing helper, then open
      // fullscreen the same way the file's other fullscreen tests do ...

      final playerWidget = tester.widget<VideoPlayerWidget>(
        find.byKey(const ValueKey('airo-tv-fullscreen-video-player')),
      );
      expect(playerWidget.enableTouchGestures, isFalse);
      expect(playerWidget.enableSwipeChannelChange, isFalse);
    },
  );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart -N "disables touch gestures"`
Expected: FAIL — `enableTouchGestures` is `true` (unset, defaults true) and `enableSwipeChannelChange` is `true`.

- [ ] **Step 3: Update both TV call sites**

Compact card call site (currently ~line 1076 in `iptv_tv_screen.dart`):

```dart
                  data: (state) => state.currentChannel == null
                      ? const _TvPlayerPlaceholder()
                      : VideoPlayerWidget(
                          showControls: true,
                          enableTouchGestures: false,
                          onFullscreenToggle: () =>
                              _openFullscreenPlayer(context),
                        ),
```

Fullscreen call site (currently ~line 1209):

```dart
          child: VideoPlayerWidget(
            key: const ValueKey('airo-tv-fullscreen-video-player'),
            showControls: true,
            enableSwipeChannelChange: false,
            enableTouchGestures: false,
            initiallyFullscreen: true,
            onFullscreenToggle: _close,
          ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/iptv_tv_screen_test.dart`
Expected: PASS — all tests in the file.

Then run the full package suite to catch any golden/snapshot test relying on the old TV player chrome:

Run: `cd packages/feature_iptv && flutter test`
Expected: PASS. If a golden test fails on TV player pixels, regenerate it per the repo's existing golden-update command (check `packages/feature_iptv/test/` for a `--update-goldens` convention before assuming one) — do not blindly delete or skip a failing golden.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart packages/feature_iptv/test/iptv/presentation/tv/iptv_tv_screen_test.dart
git commit -m "fix(feature_iptv): disable touch gestures and swipe-channel buttons on TV player"
```

---

### Task 3: Remove dead `AdaptiveIptvUI` code

**Context:** `packages/feature_iptv/lib/presentation/widgets/adaptive_iptv_ui.dart` (117 lines, defines `AdaptiveIptvUI` and `AdaptivePlayerControls`) has zero consumers anywhere in the repo — confirmed via `grep -rln "AdaptiveIptvUI\|AdaptivePlayerControls" packages/feature_iptv/lib app/lib` returning only the file's own definition, and it is not exported from any barrel file (`grep -rn "adaptive_iptv_ui" packages/feature_iptv/lib` matches nothing else). No test file references it either. This is unused code, not a half-finished feature worth reviving — TV/mobile branching in Task 1/2 is now handled directly on `VideoPlayerWidget` instead.

**Files:**
- Delete: `packages/feature_iptv/lib/presentation/widgets/adaptive_iptv_ui.dart`

- [ ] **Step 1: Re-confirm zero references (repo may have changed since this plan was written)**

Run: `grep -rln "AdaptiveIptvUI\|AdaptivePlayerControls\|adaptive_iptv_ui" packages/feature_iptv/lib app/lib packages/feature_iptv/test 2>/dev/null`
Expected: only `packages/feature_iptv/lib/presentation/widgets/adaptive_iptv_ui.dart` itself. If any other file appears, stop this task and investigate that reference instead of deleting.

- [ ] **Step 2: Delete the file**

```bash
git rm packages/feature_iptv/lib/presentation/widgets/adaptive_iptv_ui.dart
```

- [ ] **Step 3: Run the package's analyzer and full test suite**

Run: `cd packages/feature_iptv && flutter analyze && flutter test`
Expected: PASS, no broken imports.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(feature_iptv): remove unused AdaptiveIptvUI (zero consumers)"
```
