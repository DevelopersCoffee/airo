import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('Airo playback engine contract', () {
    AiroMediaOpenRequest request({
      String handle = 'source-handle-1',
      String? preferredQualityId,
    }) {
      return AiroMediaOpenRequest(
        requestId: 'open-1',
        sourceHandle: AiroPlaybackSourceHandle.redacted(handle),
        mediaKind: AiroPlaybackMediaKind.hls,
        preferredQualityId: preferredQualityId,
      );
    }

    test('source handles reject unsafe raw media references', () {
      expect(
        AiroPlaybackSourceHandle.validate(''),
        AiroPlaybackSourceHandleRejectionCode.empty,
      );
      expect(
        AiroPlaybackSourceHandle.validate('https://example.com/live.m3u8'),
        AiroPlaybackSourceHandleRejectionCode.urlValue,
      );
      expect(
        AiroPlaybackSourceHandle.validate('/Users/example/live.m3u8'),
        AiroPlaybackSourceHandleRejectionCode.localPathValue,
      );
      expect(
        AiroPlaybackSourceHandle.validate('source at 192.168.1.10'),
        AiroPlaybackSourceHandleRejectionCode.localIpValue,
      );
      expect(
        AiroPlaybackSourceHandle.validate('Bearer abc.def'),
        AiroPlaybackSourceHandleRejectionCode.credentialLikeValue,
      );
    });

    test(
      'fake engine emits open, play, pause, seek, and stop states',
      () async {
        final engine = FakeAiroPlaybackEngine();
        final events = <AiroPlaybackEnginePhase>[];
        final subscription = engine.states.listen(
          (state) => events.add(state.phase),
        );

        await engine.open(request());
        await engine.play();
        await engine.pause();
        await engine.seek(const Duration(seconds: 12));
        await engine.stop();

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();
        await engine.dispose();

        expect(events, [
          AiroPlaybackEnginePhase.opening,
          AiroPlaybackEnginePhase.open,
          AiroPlaybackEnginePhase.playing,
          AiroPlaybackEnginePhase.paused,
          AiroPlaybackEnginePhase.seeking,
          AiroPlaybackEnginePhase.paused,
          AiroPlaybackEnginePhase.stopped,
        ]);
        expect(engine.currentState.position, Duration.zero);
      },
    );

    test('fake engine selects quality and tracks deterministically', () async {
      final engine = FakeAiroPlaybackEngine(
        tracks: const [
          AiroPlaybackTrackOption(
            id: 'audio-en',
            kind: AiroPlaybackTrackKind.audio,
            label: 'English',
            languageCode: 'en',
          ),
          AiroPlaybackTrackOption(
            id: 'subs-en',
            kind: AiroPlaybackTrackKind.subtitle,
            label: 'English CC',
            languageCode: 'en',
          ),
        ],
      );

      await engine.open(request(preferredQualityId: '720p'));
      await engine.setVolume(1.5);
      await engine.setPlaybackSpeed(1.25);
      await engine.selectQuality('auto');
      await engine.selectTrack(
        kind: AiroPlaybackTrackKind.subtitle,
        trackId: 'subs-en',
      );

      expect(engine.currentState.volume, 1);
      expect(engine.currentState.playbackSpeed, 1.25);
      expect(engine.currentState.selectedQualityId, 'auto');
      expect(
        engine.currentState.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
        'subs-en',
      );
      await engine.dispose();
    });

    test('fake engine returns typed failure for unavailable options', () async {
      final engine = FakeAiroPlaybackEngine();

      await engine.open(request());
      final qualityState = await engine.selectQuality('4k');
      final trackState = await engine.selectTrack(
        kind: AiroPlaybackTrackKind.subtitle,
        trackId: 'missing',
      );

      expect(
        qualityState.error?.code,
        AiroPlaybackErrorCode.qualityUnavailable,
      );
      expect(trackState.error?.code, AiroPlaybackErrorCode.trackUnavailable);
      await engine.dispose();
    });

    test('unavailable engine returns typed unsupported state', () async {
      final engine = UnavailableAiroPlaybackEngine();

      final state = await engine.open(request());
      final diagnostics = await engine.diagnostics();

      expect(state.phase, AiroPlaybackEnginePhase.unavailable);
      expect(state.error?.code, AiroPlaybackErrorCode.backendUnavailable);
      expect(state.error?.operation, 'open');
      expect(diagnostics.backendId, 'unavailable');
      await engine.dispose();
    });

    test('string output redacts source handles', () {
      final mediaRequest = request(handle: 'opaque-source-ref');
      final state = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.open,
        request: mediaRequest,
      );

      expect(mediaRequest.toString(), isNot(contains('opaque-source-ref')));
      expect(state.toString(), isNot(contains('opaque-source-ref')));
      expect(mediaRequest.toString(), contains('sourceHandle: redacted'));
    });

    test(
      'fake engine returns unsupportedOperation for picture-in-picture',
      () async {
        final engine = FakeAiroPlaybackEngine();
        await engine.open(request());

        final enterState = await engine.enterPictureInPicture();
        expect(
          enterState.error?.code,
          AiroPlaybackErrorCode.unsupportedOperation,
        );

        final exitState = await engine.exitPictureInPicture();
        expect(
          exitState.error?.code,
          AiroPlaybackErrorCode.unsupportedOperation,
        );
        await engine.dispose();
      },
    );

    test(
      'unavailable engine returns backendUnavailable for picture-in-picture',
      () async {
        final engine = UnavailableAiroPlaybackEngine();

        final enterState = await engine.enterPictureInPicture();
        expect(enterState.error?.code, AiroPlaybackErrorCode.backendUnavailable);
        expect(enterState.error?.operation, 'enterPictureInPicture');

        final exitState = await engine.exitPictureInPicture();
        expect(exitState.error?.code, AiroPlaybackErrorCode.backendUnavailable);
        expect(exitState.error?.operation, 'exitPictureInPicture');
        await engine.dispose();
      },
    );

    test('AiroPlaybackViewFit exposes stable ids for all values', () {
      const expected = {
        AiroPlaybackViewFit.contain: 'contain',
        AiroPlaybackViewFit.cover: 'cover',
        AiroPlaybackViewFit.fill: 'fill',
        AiroPlaybackViewFit.stretch: 'stretch',
      };
      expect(
        {for (final v in AiroPlaybackViewFit.values) v: v.stableId},
        expected,
      );
    });

    test(
      'AiroMediaOpenRequest defaults to empty external subtitles',
      () {
        final mediaRequest = request();
        expect(mediaRequest.externalSubtitles, isEmpty);
      },
    );

    test(
      'AiroMediaOpenRequest accepts optional external subtitle handles',
      () {
        final mediaRequest = AiroMediaOpenRequest(
          requestId: 'open-2',
          sourceHandle: AiroPlaybackSourceHandle.redacted('source-handle-1'),
          mediaKind: AiroPlaybackMediaKind.hls,
          externalSubtitles: [
            AiroPlaybackExternalSubtitle(
              handle: AiroPlaybackSourceHandle.redacted('sub-handle-en'),
              languageCode: 'en',
              label: 'English',
            ),
          ],
        );

        expect(mediaRequest.externalSubtitles, hasLength(1));
        expect(
          mediaRequest.externalSubtitles.single.languageCode,
          'en',
        );
      },
    );

    test(
      'AiroMediaOpenRequest defaults mixWithOthers and allowBackgroundPlayback to false',
      () {
        final mediaRequest = request();
        expect(mediaRequest.mixWithOthers, isFalse);
        expect(mediaRequest.allowBackgroundPlayback, isFalse);
      },
    );

    test(
      'AiroMediaOpenRequest accepts mixWithOthers and allowBackgroundPlayback',
      () {
        final mediaRequest = AiroMediaOpenRequest(
          requestId: 'open-bg-1',
          sourceHandle: AiroPlaybackSourceHandle.redacted('source-handle-1'),
          mediaKind: AiroPlaybackMediaKind.hls,
          mixWithOthers: true,
          allowBackgroundPlayback: true,
        );
        expect(mediaRequest.mixWithOthers, isTrue);
        expect(mediaRequest.allowBackgroundPlayback, isTrue);
      },
    );

    test('external subtitle handle rejects raw urls like source handles', () {
      expect(
        AiroPlaybackSourceHandle.validate('https://example.com/en.vtt'),
        AiroPlaybackSourceHandleRejectionCode.urlValue,
      );
    });

    test('direct() accepts a raw https URL that redacted() would reject', () {
      final handle = AiroPlaybackSourceHandle.direct(
        'https://example.com/stream.m3u8?token=abc123',
      );
      expect(handle.value, 'https://example.com/stream.m3u8?token=abc123');
    });

    test('direct() accepts an Xtream-style credential-bearing URL', () {
      final handle = AiroPlaybackSourceHandle.direct(
        'http://provider.example.com/user123/pass456/789.m3u8',
      );
      expect(
        handle.value,
        'http://provider.example.com/user123/pass456/789.m3u8',
      );
    });

    test('direct() still redacts in toString()', () {
      final handle = AiroPlaybackSourceHandle.direct(
        'https://example.com/secret.m3u8?token=abc123',
      );
      expect(handle.toString(), 'AiroPlaybackSourceHandle(redacted)');
      expect(handle.toString(), isNot(contains('secret')));
      expect(handle.toString(), isNot(contains('abc123')));
    });

    test('redacted() still rejects raw URLs after direct() is added', () {
      expect(
        () => AiroPlaybackSourceHandle.redacted('https://example.com/x.m3u8'),
        throwsArgumentError,
      );
    });

    test('fake engine buildView returns a non-null placeholder after open', () async {
      final engine = FakeAiroPlaybackEngine();
      expect(engine.buildView(), isNull);

      await engine.open(request());
      final view = engine.buildView();
      expect(view, isNotNull);
      expect(
        (view!.key as ValueKey<String>).value,
        'fake-engine-view',
      );
      await engine.dispose();
    });

    test('unavailable engine buildView always returns null', () {
      final engine = UnavailableAiroPlaybackEngine();
      expect(engine.buildView(), isNull);
    });
  });

  group('externalSubtitleTracksFor', () {
    AiroMediaOpenRequest requestWith(List<AiroPlaybackExternalSubtitle> subs) {
      return AiroMediaOpenRequest(
        requestId: 'open-tracks',
        sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-1'),
        mediaKind: AiroPlaybackMediaKind.hls,
        externalSubtitles: subs,
      );
    }

    test('empty subtitles yields empty catalog', () {
      expect(externalSubtitleTracksFor(requestWith(const [])), isEmpty);
    });

    test('projects each subtitle as a subtitle track with stable id', () {
      final tracks = externalSubtitleTracksFor(
        requestWith([
          AiroPlaybackExternalSubtitle(
            handle: AiroPlaybackSourceHandle.redacted('sub-0'),
            languageCode: 'en',
            label: 'English',
          ),
          AiroPlaybackExternalSubtitle(
            handle: AiroPlaybackSourceHandle.redacted('sub-1'),
            languageCode: 'fr',
          ),
        ]),
      );

      expect(tracks, hasLength(2));
      expect(tracks[0].id, 'external_sub_0');
      expect(tracks[0].kind, AiroPlaybackTrackKind.subtitle);
      expect(tracks[0].label, 'English');
      expect(tracks[0].isExternal, isTrue);
      expect(tracks[0].languageCode, 'en');

      expect(tracks[1].id, 'external_sub_1');
      // Falls back to languageCode when label is null.
      expect(tracks[1].label, 'fr');
    });

    test('falls back to positional label when both label and language null', () {
      final tracks = externalSubtitleTracksFor(
        requestWith([
          AiroPlaybackExternalSubtitle(
            handle: AiroPlaybackSourceHandle.redacted('sub-0'),
          ),
        ]),
      );

      expect(tracks.single.label, 'External subtitle 1');
      expect(tracks.single.languageCode, isNull);
    });

    test('projected list is unmodifiable', () {
      final tracks = externalSubtitleTracksFor(
        requestWith([
          AiroPlaybackExternalSubtitle(
            handle: AiroPlaybackSourceHandle.redacted('sub-0'),
          ),
        ]),
      );
      expect(
        () => tracks.add(
          const AiroPlaybackTrackOption(
            id: 'mut',
            kind: AiroPlaybackTrackKind.subtitle,
            label: 'mut',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('AiroPlaybackBufferedRange', () {
    test('equality by start/end', () {
      const a = AiroPlaybackBufferedRange(
        start: Duration.zero,
        end: Duration(seconds: 10),
      );
      const b = AiroPlaybackBufferedRange(
        start: Duration.zero,
        end: Duration(seconds: 10),
      );
      expect(a, b);
    });
  });

  group('AiroPlaybackState.bufferedRanges', () {
    test('defaults to empty', () {
      final state = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
      );
      expect(state.bufferedRanges, isEmpty);
    });

    test('copyWith overrides bufferedRanges', () {
      final state = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
      );
      final next = state.copyWith(
        bufferedRanges: const [
          AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration(seconds: 5),
          ),
        ],
      );
      expect(next.bufferedRanges, hasLength(1));
      expect(next.bufferedRanges.single.end, const Duration(seconds: 5));
    });

    test('copyWith without bufferedRanges preserves existing value', () {
      final state = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
        bufferedRanges: const [
          AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration(seconds: 5),
          ),
        ],
      );
      final next = state.copyWith(phase: AiroPlaybackEnginePhase.playing);
      expect(next.bufferedRanges, hasLength(1));
    });

    test('bufferedRanges participates in equality', () {
      final a = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
        bufferedRanges: const [
          AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration(seconds: 5),
          ),
        ],
      );
      final b = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
      );
      expect(a, isNot(b));
    });
  });
}
