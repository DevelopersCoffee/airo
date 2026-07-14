import 'package:core_media_routing/core_media_routing.dart';
import 'package:core_sessions/core_sessions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroRouteHealthEventPolicy', () {
    const policy = AiroRouteHealthEventPolicy();
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroPlaybackOwnershipSnapshot ownership({
      String healthReporterNodeId = 'tv-1',
      DateTime? leaseExpiresAt,
    }) {
      return AiroPlaybackOwnershipSnapshot(
        sessionId: 'session-1',
        ownerNodeId: 'tv-1',
        playbackNodeId: 'tv-1',
        sourceNodeId: 'phone-1',
        routeId: 'route-1',
        routeKind: AiroMediaRouteKind.receiverDirect,
        analyticsOwnerNodeId: 'tv-1',
        healthReporterNodeId: healthReporterNodeId,
        revision: AiroSessionRevision(
          value: 4,
          updatedAt: now,
          reporterNodeId: 'tv-1',
        ),
        capturedAt: now,
        leaseExpiresAt: leaseExpiresAt,
      );
    }

    AiroRouteHealthEvent event({
      String sessionId = 'session-1',
      String routeId = 'route-1',
      String reporterNodeId = 'tv-1',
      int sequence = 1,
      AiroRouteHealthEventKind kind = AiroRouteHealthEventKind.snapshot,
      Duration? position = const Duration(seconds: 30),
      Duration? duration = const Duration(minutes: 10),
      Duration? bufferedAhead = const Duration(seconds: 15),
      int? volumePercent = 80,
      double? playbackSpeed = 1,
      AiroRouteHealthLevel healthLevel = AiroRouteHealthLevel.healthy,
      AiroRouteFailureDetail? failure,
      AiroSessionPayloadHandle? diagnosticHandle,
    }) {
      return AiroRouteHealthEvent(
        eventId: 'event-$sequence',
        sessionId: sessionId,
        routeId: routeId,
        mediaId: 'media-1',
        reporterNodeId: reporterNodeId,
        playbackNodeId: 'tv-1',
        sourceNodeId: 'phone-1',
        sequence: sequence,
        occurredAt: now,
        kind: kind,
        playbackPhase: AiroPlaybackSessionPhase.playing,
        position: position,
        duration: duration,
        bufferedAhead: bufferedAhead,
        volumePercent: volumePercent,
        isMuted: false,
        audioTrackId: 'audio-main',
        subtitleTrackId: 'sub-en',
        playbackSpeed: playbackSpeed,
        healthLevel: healthLevel,
        failure: failure,
        diagnosticHandle: diagnosticHandle,
      );
    }

    test('accepts monotonic event from current health reporter', () {
      final result = policy.validate(
        event: event(),
        ownership: ownership(),
        now: now,
      );

      expect(result.accepted, isTrue);
    });

    test('rejects wrong session route and unauthorized reporter', () {
      final result = policy.validate(
        event: event(
          sessionId: 'session-2',
          routeId: 'route-2',
          reporterNodeId: 'phone-1',
        ),
        ownership: ownership(),
        now: now,
      );

      expect(
        result.codes,
        contains(AiroRouteHealthEventValidationCode.sessionMismatch),
      );
      expect(
        result.codes,
        contains(AiroRouteHealthEventValidationCode.routeMismatch),
      );
      expect(
        result.codes,
        contains(AiroRouteHealthEventValidationCode.reporterUnauthorized),
      );
    });

    test('rejects stale or non-positive sequences', () {
      final stale = policy.validate(
        event: event(sequence: 2),
        ownership: ownership(),
        now: now,
        lastAcceptedSequence: 2,
      );
      final nonPositive = policy.validate(
        event: event(sequence: 0),
        ownership: ownership(),
        now: now,
      );

      expect(
        stale.codes,
        contains(AiroRouteHealthEventValidationCode.staleSequence),
      );
      expect(
        nonPositive.codes,
        contains(AiroRouteHealthEventValidationCode.nonPositiveSequence),
      );
    });

    test('rejects invalid playback measurements', () {
      final result = policy.validate(
        event: event(
          position: const Duration(minutes: 11),
          duration: const Duration(minutes: 10),
          bufferedAhead: const Duration(seconds: -1),
          volumePercent: 120,
          playbackSpeed: 0,
        ),
        ownership: ownership(),
        now: now,
      );

      expect(
        result.codes,
        contains(AiroRouteHealthEventValidationCode.invalidPosition),
      );
      expect(
        result.codes,
        contains(AiroRouteHealthEventValidationCode.invalidBufferedAhead),
      );
      expect(
        result.codes,
        contains(AiroRouteHealthEventValidationCode.invalidVolume),
      );
      expect(
        result.codes,
        contains(AiroRouteHealthEventValidationCode.invalidPlaybackSpeed),
      );
    });

    test('failure event requires typed failure detail', () {
      final missing = policy.validate(
        event: event(kind: AiroRouteHealthEventKind.failure, failure: null),
        ownership: ownership(),
        now: now,
      );
      final accepted = policy.validate(
        event: event(
          kind: AiroRouteHealthEventKind.failure,
          healthLevel: AiroRouteHealthLevel.failed,
          failure: const AiroRouteFailureDetail(
            category: AiroRouteFailureCategory.decoder,
            retryability: AiroRouteFailureRetryability.alternateRoute,
            stableCode: 'decoder_init_failed',
            messageBucket: 'decoder',
          ),
        ),
        ownership: ownership(),
        now: now,
      );

      expect(
        missing.codes,
        contains(AiroRouteHealthEventValidationCode.failureMissing),
      );
      expect(accepted.accepted, isTrue);
    });

    test('expired ownership rejects health reporting', () {
      final result = policy.validate(
        event: event(),
        ownership: ownership(leaseExpiresAt: now),
        now: now,
      );

      expect(
        result.codes,
        contains(AiroRouteHealthEventValidationCode.reporterUnauthorized),
      );
    });

    test('diagnostics are redacted and reject unsafe payload handles', () {
      final healthEvent = event(
        diagnosticHandle: AiroSessionPayloadHandle.redacted('health-diag-1'),
      );

      expect(healthEvent.toString(), contains('diagnosticHandle: redacted'));
      expect(healthEvent.toString(), isNot(contains('health-diag-1')));
      expect(
        () => AiroSessionPayloadHandle.redacted('https://example.com/diag'),
        throwsArgumentError,
      );
    });
  });

  group('AiroRouteHealthEventSink adapters', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    final ownership = AiroPlaybackOwnershipSnapshot(
      sessionId: 'session-1',
      ownerNodeId: 'tv-1',
      playbackNodeId: 'tv-1',
      sourceNodeId: 'phone-1',
      routeId: 'route-1',
      routeKind: AiroMediaRouteKind.receiverDirect,
      analyticsOwnerNodeId: 'tv-1',
      healthReporterNodeId: 'tv-1',
      revision: AiroSessionRevision(
        value: 4,
        updatedAt: now,
        reporterNodeId: 'tv-1',
      ),
      capturedAt: now,
    );

    AiroRouteHealthEvent event(int sequence) {
      return AiroRouteHealthEvent(
        eventId: 'event-$sequence',
        sessionId: 'session-1',
        routeId: 'route-1',
        mediaId: 'media-1',
        reporterNodeId: 'tv-1',
        playbackNodeId: 'tv-1',
        sourceNodeId: 'phone-1',
        sequence: sequence,
        occurredAt: now,
        kind: AiroRouteHealthEventKind.buffer,
        playbackPhase: AiroPlaybackSessionPhase.buffering,
        bufferedAhead: const Duration(seconds: 3),
        healthLevel: AiroRouteHealthLevel.degraded,
      );
    }

    test('no-op sink accepts event without side effects', () async {
      const sink = AiroNoOpRouteHealthEventSink();

      final result = await Future.value(sink.publish(event(1)));

      expect(result.accepted, isTrue);
    });

    test(
      'fake sink records accepted events and rejects stale events',
      () async {
        final sink = AiroFakeRouteHealthEventSink(
          ownership: ownership,
          now: now,
        );

        final first = await Future.value(sink.publish(event(1)));
        final stale = await Future.value(sink.publish(event(1)));
        final second = await Future.value(sink.publish(event(2)));

        expect(first.accepted, isTrue);
        expect(
          stale.codes,
          contains(AiroRouteHealthEventValidationCode.staleSequence),
        );
        expect(second.accepted, isTrue);
        expect(sink.events.map((event) => event.sequence), [1, 2]);
      },
    );
  });
}
