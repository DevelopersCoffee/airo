import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('AiroPlaybackSessionTracker', () {
    test('opening a session on an idle surface reports one active session', () {
      final tracker = AiroPlaybackSessionTracker();

      final event = tracker.onSessionOpened(
        surfaceId: 'tv-main',
        sessionId: 's1',
        sourceUri: Uri.parse('http://user:pw@host/live/1.ts?token=t'),
      );

      expect(event.kind, AiroPlaybackSessionEventKind.opened);
      expect(tracker.activeSessionCount('tv-main'), 1);
    });

    test('channel switch: stop before open leaves a single active session', () {
      final tracker = AiroPlaybackSessionTracker();

      tracker.onSessionOpened(surfaceId: 'tv-main', sessionId: 'a');
      tracker.onSessionStopped(surfaceId: 'tv-main', sessionId: 'a');
      tracker.onSessionOpened(surfaceId: 'tv-main', sessionId: 'b');

      expect(tracker.activeSessionCount('tv-main'), 1);
      expect(tracker.activeSessionId('tv-main'), 'b');
    });

    test(
      'duplicate open on same surface flags leak and drops older session',
      () {
        final tracker = AiroPlaybackSessionTracker();

        tracker.onSessionOpened(surfaceId: 'tv-main', sessionId: 'a');
        final event = tracker.onSessionOpened(
          surfaceId: 'tv-main',
          sessionId: 'b',
        );

        expect(event.kind, AiroPlaybackSessionEventKind.duplicateDetected);
        expect(event.evictedSessionId, 'a');
        expect(tracker.activeSessionCount('tv-main'), 1);
        expect(tracker.activeSessionId('tv-main'), 'b');
      },
    );

    test('stopping an unknown session is reported, not thrown', () {
      final tracker = AiroPlaybackSessionTracker();

      final event = tracker.onSessionStopped(
        surfaceId: 'tv-main',
        sessionId: 'ghost',
      );

      expect(event.kind, AiroPlaybackSessionEventKind.unknownSession);
      expect(tracker.activeSessionCount('tv-main'), 0);
    });

    test('surfaces are independent', () {
      final tracker = AiroPlaybackSessionTracker();

      tracker.onSessionOpened(surfaceId: 'tv-main', sessionId: 'a');
      tracker.onSessionOpened(surfaceId: 'pip', sessionId: 'b');

      expect(tracker.activeSessionCount('tv-main'), 1);
      expect(tracker.activeSessionCount('pip'), 1);
    });

    test('session events redact source uris', () {
      final tracker = AiroPlaybackSessionTracker();

      final event = tracker.onSessionOpened(
        surfaceId: 'tv-main',
        sessionId: 's1',
        sourceUri: Uri.parse(
          'http://user:secret@host:8080/live/pw/1.ts?token=abc',
        ),
      );

      expect(event.redactedSource, 'http://host:8080');
      expect(event.toString(), isNot(contains('secret')));
      expect(event.toString(), isNot(contains('token=abc')));
    });
  });
}
