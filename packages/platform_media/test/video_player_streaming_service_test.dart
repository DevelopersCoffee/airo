import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fakePlatform;
  late VideoPlayerAiroPlaybackEngine engine;
  late VideoPlayerStreamingService service;

  IPTVChannel channel({
    String streamUrl = 'https://example.com/live.m3u8',
    bool isAudioOnly = false,
    ChannelHeaders? headers,
  }) {
    return IPTVChannel(
      id: 'chan-1',
      name: 'Test Channel',
      streamUrl: streamUrl,
      isAudioOnly: isAudioOnly,
      headers: headers,
    );
  }

  setUp(() {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    engine = VideoPlayerAiroPlaybackEngine();
    service = VideoPlayerStreamingService(engine: engine);
  });

  tearDown(() async {
    await service.dispose();
  });

  group('VideoPlayerStreamingService playChannel', () {
    test('forwards playlist-supplied headers to the platform', () async {
      await service.playChannel(
        channel(
          headers: const ChannelHeaders(
            userAgent: 'Mozilla/5.0 (Airo test)',
            referrer: 'https://example.com/portal',
          ),
        ),
      );

      expect(fakePlatform.lastDataSource?.httpHeaders, {
        'User-Agent': 'Mozilla/5.0 (Airo test)',
        'Referer': 'https://example.com/portal',
      });
    });

    test('sends no headers when the playlist supplies none', () async {
      await service.playChannel(channel());

      expect(fakePlatform.lastDataSource?.httpHeaders, isEmpty);
    });

    test('opens via the injected engine and reaches playing', () async {
      await service.playChannel(channel());
      expect(service.currentState.playbackState, PlaybackState.playing);
      expect(service.currentState.currentChannel?.id, 'chan-1');
    });

    test(
      'decoder failure surfaces as a typed error and retry count increments',
      () async {
        fakePlatform.scriptedInitError = PlatformException(
          code: 'VideoError',
          message: 'decoder rejected format',
        );
        await service.playChannel(channel());
        expect(service.currentState.playbackState, PlaybackState.error);
        expect(service.currentState.retryCount, 1);
        // CV-016 diagnostic-mapping fix: the engine's typed decoderFailed
        // code must be mapped directly (-> playerInitFailed), not
        // round-tripped through the CV-001 string-pattern matcher, which
        // would have no substring/regex match for "decoder_failed" and fall
        // through to the generic `unknown` diagnostic.
        expect(
          service.currentState.diagnostic?.code,
          AiroPlaybackDiagnosticCode.playerInitFailed,
        );
      },
    );

    test('network-unavailable engine failure maps to a precise network '
        'diagnostic, not the generic unknown fallback', () async {
      // VideoPlayerAiroPlaybackEngine can only be driven to
      // decoderFailed/backendUnavailable through FakeVideoPlayerPlatform
      // (video_player hard-casts init-stream errors to
      // PlatformException, so a TimeoutException can't reach it — see
      // FakeVideoPlayerPlatform.scriptedInitError). A directly-injected
      // engine double is used instead so this test can drive the
      // networkUnavailable code specifically.
      final networkFailureEngine = _ScriptedOpenFailureEngine(
        AiroPlaybackErrorCode.networkUnavailable,
      );
      final networkService = VideoPlayerStreamingService(
        engine: networkFailureEngine,
      );
      addTearDown(networkService.dispose);

      await networkService.playChannel(channel());

      expect(networkService.currentState.playbackState, PlaybackState.error);
      // CV-016 diagnostic-mapping fix: this is the headline regression —
      // before the fix, the engine's typed networkUnavailable code was
      // stringified and round-tripped through the CV-001 string-pattern
      // mapper, which has no match for "network_unavailable" and fell
      // through to the generic unknown diagnostic.
      expect(
        networkService.currentState.diagnostic?.code,
        AiroPlaybackDiagnosticCode.networkUnavailable,
      );
      expect(
        networkService.currentState.diagnostic?.code,
        isNot(AiroPlaybackDiagnosticCode.unknown),
      );
    });

    test('HTTP 403 open failure maps to providerAuthDenied (honest blame), '
        'not playerInitFailed', () async {
      // rc.3 device-pass regression: a geo-blocked/403 channel surfaced
      // as "Playback could not start on this device" because the HTTP
      // status never reached the diagnostic mapper. The engine now
      // extracts it onto AiroPlaybackError.httpStatusCode and the
      // service threads it into AiroPlaybackFailureEvent, whose mapper
      // prioritizes httpStatusCode over the engine error code.
      final geoBlockedEngine = _ScriptedOpenFailureEngine(
        AiroPlaybackErrorCode.decoderFailed,
        httpStatusCode: 403,
      );
      final geoBlockedService = VideoPlayerStreamingService(
        engine: geoBlockedEngine,
      );
      addTearDown(geoBlockedService.dispose);

      await geoBlockedService.playChannel(channel());

      expect(geoBlockedService.currentState.playbackState, PlaybackState.error);
      final diagnostic = geoBlockedService.currentState.diagnostic;
      expect(diagnostic?.code, AiroPlaybackDiagnosticCode.providerAuthDenied);
      expect(diagnostic?.retryEligible, isFalse);
      expect(diagnostic?.userMessage, contains('provider'));
      expect(diagnostic?.technicalDetail, contains('http=403'));
    });

    test('buildVideoView returns non-null after a successful open', () async {
      await service.playChannel(channel());
      expect(service.buildVideoView(), isNotNull);
    });

    test('buildVideoView returns null before any channel is played', () {
      expect(service.buildVideoView(), isNull);
    });

    test(
      'an audio-only channel opens with allowBackgroundPlayback true',
      () async {
        await service.playChannel(channel(isAudioOnly: true));

        // The service doesn't expose the engine or the raw controller, but
        // the engine retains the last-opened AiroMediaOpenRequest on its own
        // state (see VideoPlayerAiroPlaybackEngine.open()'s
        // `_emit(_state.copyWith(request: request, ...))`), so we can
        // observe the request that reached VideoPlayerController via the
        // injected engine instance from setUp.
        final openedRequest = engine.currentState.request;
        expect(openedRequest, isNotNull);
        expect(openedRequest!.allowBackgroundPlayback, isTrue);
      },
    );

    test(
      'a non-audio-only channel opens with allowBackgroundPlayback false by default',
      () async {
        await service.playChannel(channel());

        final openedRequest = engine.currentState.request;
        expect(openedRequest, isNotNull);
        expect(openedRequest!.allowBackgroundPlayback, isFalse);
      },
    );

    test(
      'enabling background audio mode sets mixWithOthers and allowBackgroundPlayback',
      () async {
        await service.playChannel(channel());
        await service.setBackgroundAudioMode(true);

        final openedRequest = engine.currentState.request;
        expect(openedRequest, isNotNull);
        expect(openedRequest!.mixWithOthers, isTrue);
        expect(openedRequest.allowBackgroundPlayback, isTrue);
      },
    );
  });

  group('VideoPlayerStreamingService multi-source failover', () {
    const urlA = 'https://a.example.com/live.m3u8';
    const urlB = 'https://b.example.com/live.m3u8';

    IPTVChannel multiSourceChannel() {
      return IPTVChannel(
        id: 'chan-multi',
        name: 'Multi Source Channel',
        streamUrl: urlA,
        qualityUrls: const {'high': urlB},
      );
    }

    VideoPlayerStreamingService serviceWith(AiroPlaybackEngine scripted) {
      // Zero retryDelay: these tests assert retry()'s failover-selection
      // logic (does it advance to the next source, does exhaustion surface
      // correctly), not the debounce timing covered separately by the
      // 'retry debounce' group below -- an instant programmatic retry()
      // call here should not be mistaken for the human button-mashing the
      // debounce guards against.
      final svc = VideoPlayerStreamingService(
        engine: scripted,
        config: const StreamingConfig(retryDelay: Duration.zero),
      );
      addTearDown(svc.dispose);
      return svc;
    }

    test(
      'fatal 403 on the primary source auto-fails over to the next source',
      () async {
        final scripted = _ScriptedMultiSourceEngine({
          urlA: const AiroPlaybackError(
            code: AiroPlaybackErrorCode.decoderFailed,
            operation: 'open',
            httpStatusCode: 403,
          ),
        });
        final svc = serviceWith(scripted);
        final states = <StreamingState>[];
        final sub = svc.stateStream.listen(states.add);
        addTearDown(sub.cancel);

        await svc.playChannel(multiSourceChannel());

        expect(svc.currentState.playbackState, PlaybackState.playing);
        expect(scripted.openedUrls, [urlA, urlB]);
        // Failover progress was surfaced while the switch was in flight,
        // then cleared on success.
        expect(
          states.any(
            (s) =>
                s.failover ==
                const FailoverProgress(currentSource: 2, totalSources: 2),
          ),
          isTrue,
        );
        expect(svc.currentState.failover, isNull);
        expect(svc.currentState.diagnostic, isNull);
      },
    );

    test(
      'recoverable failure on the primary does NOT auto-fail over',
      () async {
        final scripted = _ScriptedMultiSourceEngine({
          urlA: const AiroPlaybackError(
            code: AiroPlaybackErrorCode.networkUnavailable,
            operation: 'open',
          ),
        });
        final svc = serviceWith(scripted);

        await svc.playChannel(multiSourceChannel());

        expect(svc.currentState.playbackState, PlaybackState.error);
        expect(scripted.openedUrls, [urlA]);
        expect(
          svc.currentState.diagnostic?.code,
          AiroPlaybackDiagnosticCode.networkUnavailable,
        );
        expect(svc.currentState.failover, isNull);
      },
    );

    test(
      'exhausted failover surfaces the final source diagnostic error',
      () async {
        final scripted = _ScriptedMultiSourceEngine({
          urlA: const AiroPlaybackError(
            code: AiroPlaybackErrorCode.decoderFailed,
            operation: 'open',
            httpStatusCode: 403,
          ),
          urlB: const AiroPlaybackError(
            code: AiroPlaybackErrorCode.decoderFailed,
            operation: 'open',
            httpStatusCode: 404,
          ),
        });
        final svc = serviceWith(scripted);

        await svc.playChannel(multiSourceChannel());

        expect(svc.currentState.playbackState, PlaybackState.error);
        expect(scripted.openedUrls, [urlA, urlB]);
        expect(
          svc.currentState.diagnostic?.code,
          AiroPlaybackDiagnosticCode.providerNotFound,
        );
        expect(svc.currentState.failover, isNull);
      },
    );

    test('retry attempts failover before resubmitting the dead URL', () async {
      final scripted = _ScriptedMultiSourceEngine({
        urlA: const AiroPlaybackError(
          code: AiroPlaybackErrorCode.networkUnavailable,
          operation: 'open',
        ),
      });
      final svc = serviceWith(scripted);

      await svc.playChannel(multiSourceChannel());
      expect(svc.currentState.playbackState, PlaybackState.error);
      expect(scripted.openedUrls, [urlA]);

      await svc.retry();

      // urlB never fails — retry must land on it instead of replaying
      // the dead primary.
      expect(scripted.openedUrls, [urlA, urlB]);
      expect(svc.currentState.playbackState, PlaybackState.playing);
    });

    test(
      'single-source channel retry keeps the legacy re-open behavior',
      () async {
        final scripted = _ScriptedMultiSourceEngine({
          'https://example.com/live.m3u8': const AiroPlaybackError(
            code: AiroPlaybackErrorCode.networkUnavailable,
            operation: 'open',
          ),
        });
        final svc = serviceWith(scripted);

        await svc.playChannel(channel());
        expect(svc.currentState.playbackState, PlaybackState.error);

        await svc.retry();

        expect(scripted.openedUrls, [
          'https://example.com/live.m3u8',
          'https://example.com/live.m3u8',
        ]);
        expect(svc.currentState.playbackState, PlaybackState.error);
      },
    );

    // AiroMultiSourceFailoverController.recordBuffering/
    // shouldFailoverForStall (4s threshold) previously had no caller in
    // this service; the 1s buffer-monitor timer only updated a display
    // bufferHealth percentage. These tests exercise the wiring added to
    // close that gap.
    test('sustained buffering past the stall threshold fails over to the '
        'next source', () async {
      final scripted = _StallableMultiSourceEngine();
      final svc = serviceWith(scripted);

      await svc.playChannel(multiSourceChannel());
      expect(scripted.openedUrls, [urlA]);

      scripted.setBuffering(true);
      // Policy threshold is 4s; wait well past it to absorb Timer.periodic
      // scheduling jitter under load rather than racing a tight margin.
      await Future<void>.delayed(const Duration(milliseconds: 8000));

      expect(scripted.openedUrls, [urlA, urlB]);
      expect(svc.currentState.playbackState, PlaybackState.playing);
      expect(svc.currentState.failover, isNull);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test(
      'buffering that clears before the stall threshold does not fail over',
      () async {
        final scripted = _StallableMultiSourceEngine();
        final svc = serviceWith(scripted);

        await svc.playChannel(multiSourceChannel());
        scripted.setBuffering(true);
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        scripted.setBuffering(false);
        await Future<void>.delayed(const Duration(milliseconds: 1500));

        expect(scripted.openedUrls, [urlA]);
        expect(svc.currentState.playbackState, PlaybackState.playing);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test('sustained buffering with no remaining source reaches the terminal '
        'error state', () async {
      final scripted = _StallableMultiSourceEngine();
      final svc = serviceWith(scripted);

      await svc.playChannel(channel());
      scripted.setBuffering(true);
      await Future<void>.delayed(const Duration(milliseconds: 8000));

      expect(svc.currentState.playbackState, PlaybackState.error);
      expect(svc.currentState.failover, isNull);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('a stall on the switched-to source after an initial switch reaches '
        'exhausted, not an instant or stuck re-trigger', () async {
      // Exercises the one new piece of state central to this wiring:
      // _startBufferMonitoring() resets _bufferingSince on every restart,
      // including the one triggered by a stall-driven switch. A stale
      // _bufferingSince would either fire the second stall instantly
      // (reset never happened) or never re-arm (reset happened but the
      // new episode's start was lost).
      final scripted = _StallableMultiSourceEngine();
      final svc = serviceWith(scripted);

      await svc.playChannel(multiSourceChannel());
      scripted.setBuffering(true);
      await Future<void>.delayed(const Duration(milliseconds: 8000));

      expect(scripted.openedUrls, [urlA, urlB]);
      expect(svc.currentState.playbackState, PlaybackState.playing);

      // The switch's own open() reset phase to `.open`, clearing
      // isBuffering -- stall a second time on the new (and now only
      // remaining) source.
      scripted.setBuffering(true);
      await Future<void>.delayed(const Duration(milliseconds: 8000));

      expect(scripted.openedUrls, [urlA, urlB]);
      expect(svc.currentState.playbackState, PlaybackState.error);
      expect(svc.currentState.failover, isNull);
    }, timeout: const Timeout(Duration(seconds: 25)));

    test('retry exhaustion explains a dead or region-blocked stream', () async {
      final scripted = _ScriptedOpenFailureEngine(
        AiroPlaybackErrorCode.networkUnavailable,
      );
      // Zero retryDelay: asserts retry-count/exhaustion logic across
      // repeated retry() calls, not debounce timing (covered separately).
      // maxRetries: 5 preserves this test's original assumption (the
      // previously-implicit StreamingConfig.youtube default) -- the plain
      // StreamingConfig() constructor's own default is 3, not 5.
      final svc = VideoPlayerStreamingService(
        engine: scripted,
        config: const StreamingConfig(retryDelay: Duration.zero, maxRetries: 5),
      );
      addTearDown(svc.dispose);

      await svc.playChannel(channel());
      for (var attempt = 0; attempt < 4; attempt++) {
        await svc.retry();
      }

      expect(svc.currentState.retryCount, 5);
      expect(svc.currentState.errorMessage, startsWith('Playback failed:'));

      await svc.retry();

      expect(svc.currentState.playbackState, PlaybackState.error);
      expect(svc.currentState.retryCount, 6);
      expect(
        svc.currentState.errorMessage,
        'This channel may be blocked in your region or not currently '
        'broadcasting.',
      );
      expect(
        svc.currentState.diagnostic?.userMessage,
        svc.currentState.errorMessage,
      );
      expect(svc.currentState.diagnostic?.retryEligible, isFalse);
    });
  });

  group('VideoPlayerStreamingService retry debounce', () {
    // StreamingConfig.retryDelay existed but was never read anywhere --
    // retry() now uses it to rate-limit how fast a manual "Try Again" tap
    // can resubmit, without making retry auto-triggered (that would
    // reverse the deliberate manual-only decision documented on
    // _handleError).
    IPTVChannel channel() {
      return const IPTVChannel(
        id: 'chan-1',
        name: 'Test Channel',
        streamUrl: 'https://example.com/live.m3u8',
      );
    }

    test('a retry within retryDelay of the last failure is a no-op', () async {
      final engine = _ScriptedOpenFailureEngine(
        AiroPlaybackErrorCode.networkUnavailable,
      );
      final svc = VideoPlayerStreamingService(
        engine: engine,
        config: const StreamingConfig(retryDelay: Duration(seconds: 1)),
      );
      addTearDown(svc.dispose);

      await svc.playChannel(channel());
      expect(svc.currentState.playbackState, PlaybackState.error);
      expect(svc.currentState.retryCount, 1);

      await svc.retry();

      // Debounced: no new attempt, retryCount unchanged.
      expect(svc.currentState.retryCount, 1);
    });

    test('a retry after retryDelay has elapsed proceeds normally', () async {
      final engine = _ScriptedOpenFailureEngine(
        AiroPlaybackErrorCode.networkUnavailable,
      );
      final svc = VideoPlayerStreamingService(
        engine: engine,
        config: const StreamingConfig(retryDelay: Duration(milliseconds: 50)),
      );
      addTearDown(svc.dispose);

      await svc.playChannel(channel());
      expect(svc.currentState.retryCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      await svc.retry();

      expect(svc.currentState.retryCount, 2);
    });

    test('a retry while still loading is a no-op', () async {
      final engine = _PendingOpenEngine();
      final svc = VideoPlayerStreamingService(
        engine: engine,
        config: const StreamingConfig(retryDelay: Duration.zero),
      );
      addTearDown(svc.dispose);

      final playFuture = svc.playChannel(channel());
      await Future<void>.delayed(Duration.zero);
      expect(svc.currentState.playbackState, PlaybackState.loading);

      await svc.retry();
      expect(engine.openCallCount, 1);

      engine.completeOpen();
      await playFuture;
    });
  });

  group('VideoPlayerStreamingService seek', () {
    test(
      'seek during active playback keeps playbackState playing (isPlaying true)',
      () async {
        await service.playChannel(channel());
        expect(service.currentState.playbackState, PlaybackState.playing);
        expect(service.currentState.isPlaying, isTrue);

        await service.seek(const Duration(seconds: 30));

        expect(service.currentState.playbackState, PlaybackState.playing);
        expect(service.currentState.isPlaying, isTrue);
      },
    );
  });

  group('VideoPlayerStreamingService selectTrack', () {
    test('unknown track id is a no-op that does not throw', () async {
      await service.playChannel(channel());
      await service.selectTrack(
        kind: AiroPlaybackTrackKind.subtitle,
        trackId: 'nonexistent',
      );
      expect(
        service.currentState.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
        isNull,
      );
    });

    test(
      'clearTrackSelection turns subtitles off without stopping playback',
      () async {
        service.attachExternalSubtitle(
          'chan-1',
          AiroPlaybackExternalSubtitle(
            handle: AiroPlaybackSourceHandle.redacted('sub-en'),
            languageCode: 'en',
            label: 'English',
          ),
        );
        await service.playChannel(channel());
        await service.selectTrack(
          kind: AiroPlaybackTrackKind.subtitle,
          trackId: 'external_sub_0',
        );
        expect(
          service.currentState.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
          'external_sub_0',
        );

        await service.clearTrackSelection(AiroPlaybackTrackKind.subtitle);

        expect(
          service.currentState.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
          isNull,
        );
        expect(service.currentState.playbackState, PlaybackState.playing);
      },
    );
  });

  group('VideoPlayerStreamingService attachExternalSubtitle', () {
    test(
      'attached subtitle appears in tracks after the next playChannel',
      () async {
        service.attachExternalSubtitle(
          'chan-1',
          AiroPlaybackExternalSubtitle(
            handle: AiroPlaybackSourceHandle.redacted('sub-en'),
            languageCode: 'en',
            label: 'English',
          ),
        );
        await service.playChannel(channel());
        expect(service.currentState.tracks, hasLength(1));
        expect(service.currentState.tracks.single.isExternal, isTrue);
      },
    );

    test('subtitle does not appear before the next playChannel', () async {
      await service.playChannel(channel());
      expect(service.currentState.tracks, isEmpty);

      service.attachExternalSubtitle(
        'chan-1',
        AiroPlaybackExternalSubtitle(
          handle: AiroPlaybackSourceHandle.redacted('sub-en'),
          languageCode: 'en',
        ),
      );
      // Not applied yet — still empty until the next playChannel.
      expect(service.currentState.tracks, isEmpty);
    });

    test(
      'subtitle attached for one item does not leak onto a different item',
      () async {
        // Attach for chan-1 and play chan-1: subtitle should appear.
        service.attachExternalSubtitle(
          'chan-1',
          AiroPlaybackExternalSubtitle(
            handle: AiroPlaybackSourceHandle.redacted('sub-en'),
            languageCode: 'en',
            label: 'English',
          ),
        );
        await service.playChannel(channel());
        expect(service.currentState.tracks, hasLength(1));
        expect(service.currentState.tracks.single.isExternal, isTrue);

        // Playing a *different* channel/item must NOT inherit chan-1's
        // pending subtitle (this is the CV-016 review Finding 2 leak).
        final otherChannel = IPTVChannel(
          id: 'chan-2',
          name: 'Other Channel',
          streamUrl: 'https://example.com/other.m3u8',
        );
        await service.playChannel(otherChannel);
        expect(service.currentState.tracks, isEmpty);
      },
    );

    test(
      'a quality switch (same channel id) still re-applies the pending subtitle',
      () async {
        // setQuality() re-invokes playChannel() for the *same* channel id —
        // the id-matching scope must not treat that as "a different item".
        service.attachExternalSubtitle(
          'chan-1',
          AiroPlaybackExternalSubtitle(
            handle: AiroPlaybackSourceHandle.redacted('sub-en'),
            languageCode: 'en',
            label: 'English',
          ),
        );
        await service.playChannel(channel());
        expect(service.currentState.tracks, hasLength(1));

        await service.setQuality(VideoQuality.high);
        expect(service.currentState.tracks, hasLength(1));
        expect(service.currentState.tracks.single.isExternal, isTrue);
      },
    );
  });

  group('VideoPlayerStreamingService DVR/live-edge/buffer-health regression', () {
    test(
      'a stream with a large finite duration is classified as VOD (isLiveStream false)',
      () async {
        final vodService = VideoPlayerStreamingService(
          engine: VideoPlayerAiroPlaybackEngine(),
          liveEdgeConfig: const LiveEdgeConfig(
            updateInterval: Duration(milliseconds: 50),
          ),
        );
        addTearDown(vodService.dispose);

        fakePlatform = FakeVideoPlayerPlatform(
          fakeDuration: const Duration(minutes: 90),
        );
        VideoPlayerPlatform.instance = fakePlatform;

        await vodService.playChannel(channel());
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(vodService.currentState.isLiveStream, isFalse);
      },
    );

    test(
      'a stream with zero duration is classified as live (isLiveStream true)',
      () async {
        final liveService = VideoPlayerStreamingService(
          engine: VideoPlayerAiroPlaybackEngine(),
          liveEdgeConfig: const LiveEdgeConfig(
            updateInterval: Duration(milliseconds: 50),
          ),
        );
        addTearDown(liveService.dispose);

        fakePlatform = FakeVideoPlayerPlatform(fakeDuration: Duration.zero);
        VideoPlayerPlatform.instance = fakePlatform;

        await liveService.playChannel(channel());
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(liveService.currentState.isLiveStream, isTrue);
      },
    );

    test(
      'buffer-health monitor recalculates bufferHealth from the default 100',
      () async {
        // BufferStatus() defaults bufferHealth to 100 (the pristine,
        // pre-timer value). FakeVideoPlayerPlatform never scripts buffered
        // DurationRanges, so bufferedAhead is deterministically zero once
        // the 1s Timer.periodic in _startBufferMonitoring ticks — driving
        // bufferHealth to 0 (0 / targetBufferDuration * 100). Seeing 0
        // instead of the untouched default of 100 is what proves the timer
        // actually ran, not just that BufferStatus has a value.
        await service.playChannel(channel());
        expect(service.currentState.bufferStatus.bufferHealth, 100);

        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(service.currentState.bufferStatus.bufferHealth, 0);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });
}

/// Minimal [AiroPlaybackEngine] double whose [open] always fails with a
/// caller-chosen [AiroPlaybackErrorCode] (see the network-unavailable
/// diagnostic-mapping test above). Deliberately not a
/// `FakeAiroPlaybackEngine` subclass: that fake's failure hooks
/// (`selectQuality`/`selectTrack`) only cover
/// `qualityUnavailable`/`trackUnavailable`, and its `_fail`/`_emit` helpers
/// are private to `platform_player`, so an arbitrary open()-time error code
/// isn't reachable through it from another package's test.
class _ScriptedOpenFailureEngine implements AiroPlaybackEngine {
  _ScriptedOpenFailureEngine(this._errorCode, {this.httpStatusCode});

  final AiroPlaybackErrorCode _errorCode;
  final int? httpStatusCode;
  final _controller = StreamController<AiroPlaybackState>.broadcast();
  AiroPlaybackState _state = AiroPlaybackState.idle(
    backendKind: AiroPlaybackBackendKind.fake,
  );

  @override
  AiroPlaybackBackendKind get backendKind => AiroPlaybackBackendKind.fake;

  @override
  Stream<AiroPlaybackState> get states => _controller.stream;

  @override
  AiroPlaybackState get currentState => _state;

  @override
  Future<AiroPlaybackState> open(AiroMediaOpenRequest request) async {
    _state = _state.copyWith(
      phase: AiroPlaybackEnginePhase.failed,
      request: request,
      error: AiroPlaybackError(
        code: _errorCode,
        operation: 'open',
        httpStatusCode: httpStatusCode,
      ),
    );
    _controller.add(_state);
    return _state;
  }

  @override
  Future<AiroPlaybackState> play() async => _state;

  @override
  Future<AiroPlaybackState> pause() async => _state;

  @override
  Future<AiroPlaybackState> stop() async => _state;

  @override
  Future<AiroPlaybackState> seek(Duration position) async => _state;

  @override
  Future<AiroPlaybackState> setVolume(double volume) async => _state;

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async => _state;

  @override
  Future<AiroPlaybackState> selectQuality(String qualityId) async => _state;

  @override
  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async => _state;

  @override
  Future<AiroPlaybackState> clearTrackSelection(
    AiroPlaybackTrackKind kind,
  ) async => _state;

  @override
  Future<AiroPlaybackDiagnostics> diagnostics() async =>
      AiroPlaybackDiagnostics(backendId: backendKind.stableId);

  @override
  Future<AiroPlaybackState> enterPictureInPicture() async => _state;

  @override
  Future<AiroPlaybackState> exitPictureInPicture() async => _state;

  @override
  Widget? buildView() => null;

  @override
  Future<void> dispose() async => _controller.close();
}

/// Handle-aware engine double for the multi-source failover tests: fails
/// [open] with the scripted [AiroPlaybackError] for URLs present in
/// [_failuresByUrl], succeeds otherwise, and records every opened URL in
/// [openedUrls] so tests can assert exactly which sources were attempted.
class _ScriptedMultiSourceEngine implements AiroPlaybackEngine {
  _ScriptedMultiSourceEngine(this._failuresByUrl);

  final Map<String, AiroPlaybackError> _failuresByUrl;
  final openedUrls = <String>[];
  final _controller = StreamController<AiroPlaybackState>.broadcast();
  AiroPlaybackState _state = AiroPlaybackState.idle(
    backendKind: AiroPlaybackBackendKind.fake,
  );

  @override
  AiroPlaybackBackendKind get backendKind => AiroPlaybackBackendKind.fake;

  @override
  Stream<AiroPlaybackState> get states => _controller.stream;

  @override
  AiroPlaybackState get currentState => _state;

  @override
  Future<AiroPlaybackState> open(AiroMediaOpenRequest request) async {
    openedUrls.add(request.sourceHandle.value);
    final failure = _failuresByUrl[request.sourceHandle.value];
    if (failure != null) {
      _state = _state.copyWith(
        phase: AiroPlaybackEnginePhase.failed,
        request: request,
        error: failure,
      );
    } else {
      _state = _state.copyWith(
        phase: AiroPlaybackEnginePhase.open,
        request: request,
        duration: const Duration(minutes: 30),
      );
    }
    _controller.add(_state);
    return _state;
  }

  @override
  Future<AiroPlaybackState> play() async => _state;

  @override
  Future<AiroPlaybackState> pause() async => _state;

  @override
  Future<AiroPlaybackState> stop() async => _state;

  @override
  Future<AiroPlaybackState> seek(Duration position) async => _state;

  @override
  Future<AiroPlaybackState> setVolume(double volume) async => _state;

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async => _state;

  @override
  Future<AiroPlaybackState> selectQuality(String qualityId) async => _state;

  @override
  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async => _state;

  @override
  Future<AiroPlaybackState> clearTrackSelection(
    AiroPlaybackTrackKind kind,
  ) async => _state;

  @override
  Future<AiroPlaybackDiagnostics> diagnostics() async =>
      AiroPlaybackDiagnostics(backendId: backendKind.stableId);

  @override
  Future<AiroPlaybackState> enterPictureInPicture() async => _state;

  @override
  Future<AiroPlaybackState> exitPictureInPicture() async => _state;

  @override
  Widget? buildView() => null;

  @override
  Future<void> dispose() async => _controller.close();
}

/// Like [_ScriptedMultiSourceEngine] (every `open()` succeeds), plus
/// [setBuffering] to drive the stall-failover tests: the buffer monitor
/// reads `_engine.currentState.phase` directly, and any subsequent
/// `open()` call (a failover switch) naturally resets it away from
/// `buffering`, matching a real engine's behavior on source switch.
class _StallableMultiSourceEngine implements AiroPlaybackEngine {
  final openedUrls = <String>[];
  final _controller = StreamController<AiroPlaybackState>.broadcast();
  AiroPlaybackState _state = AiroPlaybackState.idle(
    backendKind: AiroPlaybackBackendKind.fake,
  );

  void setBuffering(bool buffering) {
    _state = _state.copyWith(
      phase: buffering
          ? AiroPlaybackEnginePhase.buffering
          : AiroPlaybackEnginePhase.open,
    );
  }

  @override
  AiroPlaybackBackendKind get backendKind => AiroPlaybackBackendKind.fake;

  @override
  Stream<AiroPlaybackState> get states => _controller.stream;

  @override
  AiroPlaybackState get currentState => _state;

  @override
  Future<AiroPlaybackState> open(AiroMediaOpenRequest request) async {
    openedUrls.add(request.sourceHandle.value);
    _state = _state.copyWith(
      phase: AiroPlaybackEnginePhase.open,
      request: request,
      duration: const Duration(minutes: 30),
    );
    _controller.add(_state);
    return _state;
  }

  @override
  Future<AiroPlaybackState> play() async => _state;

  @override
  Future<AiroPlaybackState> pause() async => _state;

  @override
  Future<AiroPlaybackState> stop() async => _state;

  @override
  Future<AiroPlaybackState> seek(Duration position) async => _state;

  @override
  Future<AiroPlaybackState> setVolume(double volume) async => _state;

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async => _state;

  @override
  Future<AiroPlaybackState> selectQuality(String qualityId) async => _state;

  @override
  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async => _state;

  @override
  Future<AiroPlaybackState> clearTrackSelection(
    AiroPlaybackTrackKind kind,
  ) async => _state;

  @override
  Future<AiroPlaybackDiagnostics> diagnostics() async =>
      AiroPlaybackDiagnostics(backendId: backendKind.stableId);

  @override
  Future<AiroPlaybackState> enterPictureInPicture() async => _state;

  @override
  Future<AiroPlaybackState> exitPictureInPicture() async => _state;

  @override
  Widget? buildView() => null;

  @override
  Future<void> dispose() async => _controller.close();
}

/// An [AiroPlaybackEngine] whose `open()` never resolves until the test
/// calls [completeOpen] -- used to hold [VideoPlayerStreamingService] in
/// `PlaybackState.loading` so a concurrent retry() call during that window
/// can be observed as a no-op.
class _PendingOpenEngine implements AiroPlaybackEngine {
  int openCallCount = 0;
  final _openCompleter = Completer<AiroPlaybackState>();
  final _controller = StreamController<AiroPlaybackState>.broadcast();
  AiroPlaybackState _state = AiroPlaybackState.idle(
    backendKind: AiroPlaybackBackendKind.fake,
  );

  void completeOpen() {
    _state = _state.copyWith(phase: AiroPlaybackEnginePhase.open);
    if (!_openCompleter.isCompleted) _openCompleter.complete(_state);
  }

  @override
  AiroPlaybackBackendKind get backendKind => AiroPlaybackBackendKind.fake;

  @override
  Stream<AiroPlaybackState> get states => _controller.stream;

  @override
  AiroPlaybackState get currentState => _state;

  @override
  Future<AiroPlaybackState> open(AiroMediaOpenRequest request) async {
    openCallCount++;
    return _openCompleter.future;
  }

  @override
  Future<AiroPlaybackState> play() async => _state;

  @override
  Future<AiroPlaybackState> pause() async => _state;

  @override
  Future<AiroPlaybackState> stop() async => _state;

  @override
  Future<AiroPlaybackState> seek(Duration position) async => _state;

  @override
  Future<AiroPlaybackState> setVolume(double volume) async => _state;

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async => _state;

  @override
  Future<AiroPlaybackState> selectQuality(String qualityId) async => _state;

  @override
  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async => _state;

  @override
  Future<AiroPlaybackState> clearTrackSelection(
    AiroPlaybackTrackKind kind,
  ) async => _state;

  @override
  Future<AiroPlaybackDiagnostics> diagnostics() async =>
      AiroPlaybackDiagnostics(backendId: backendKind.stableId);

  @override
  Future<AiroPlaybackState> enterPictureInPicture() async => _state;

  @override
  Future<AiroPlaybackState> exitPictureInPicture() async => _state;

  @override
  Widget? buildView() => null;

  @override
  Future<void> dispose() async => _controller.close();
}
