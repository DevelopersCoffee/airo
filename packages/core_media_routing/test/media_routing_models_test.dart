import 'package:core_media_routing/core_media_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroDeterministicMediaRoutingEngine', () {
    const engine = AiroDeterministicMediaRoutingEngine();
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroMediaRouteCandidate candidate({
      required String id,
      required AiroMediaRouteKind kind,
      AiroMediaSourceKind sourceKind = AiroMediaSourceKind.iptv,
      Set<String> codecs = const {'h264', 'aac'},
      bool available = true,
      bool trusted = true,
      bool direct = true,
      DateTime? expiresAt,
    }) {
      return AiroMediaRouteCandidate(
        candidateId: id,
        kind: kind,
        sourceKind: sourceKind,
        sourceHandle: AiroMediaRouteSourceHandle.redacted('source-$id'),
        playbackNodeId: 'receiver-1',
        sourceNodeId: 'source-1',
        supportedCodecs: codecs,
        isAvailable: available,
        isTrusted: trusted,
        supportsDirectPlayback: direct,
        expiresAt: expiresAt,
      );
    }

    AiroMediaRouteRequest request({
      required List<AiroMediaRouteCandidate> candidates,
      bool userConfirmedPhoneProxy = false,
      Set<String> requiredCodecs = const {'h264', 'aac'},
    }) {
      return AiroMediaRouteRequest(
        requestId: 'request-1',
        intent: AiroMediaRouteIntent.play,
        requestedAt: now,
        candidates: candidates,
        requiredCodecs: requiredCodecs,
        userConfirmedPhoneProxy: userConfirmedPhoneProxy,
      );
    }

    test('selects direct receiver route before phone proxy', () {
      final direct = candidate(
        id: 'direct',
        kind: AiroMediaRouteKind.receiverDirect,
      );
      final phone = candidate(
        id: 'phone',
        kind: AiroMediaRouteKind.phoneProxy,
        sourceKind: AiroMediaSourceKind.phoneLocal,
      );

      final decision = engine.selectRoute(
        request(candidates: [phone, direct], userConfirmedPhoneProxy: true),
      );

      expect(decision.selected?.candidate, direct);
      expect(decision.selectedKind, AiroMediaRouteKind.receiverDirect);
      expect(
        decision.rejected
            .singleWhere((evaluation) => evaluation.candidate == phone)
            .blockers,
        contains(AiroMediaRouteBlockerCode.phoneProxyRequiresConfirmation),
      );
    });

    test(
      'selects phone proxy only when confirmed and no direct route exists',
      () {
        final phone = candidate(
          id: 'phone',
          kind: AiroMediaRouteKind.phoneProxy,
          sourceKind: AiroMediaSourceKind.phoneLocal,
        );

        final decision = engine.selectRoute(
          request(candidates: [phone], userConfirmedPhoneProxy: true),
        );

        expect(decision.selected?.candidate, phone);
        expect(decision.selectedKind, AiroMediaRouteKind.phoneProxy);
        expect(decision.hasRoute, isTrue);
      },
    );

    test('rejects phone proxy without user confirmation', () {
      final phone = candidate(
        id: 'phone',
        kind: AiroMediaRouteKind.phoneProxy,
        sourceKind: AiroMediaSourceKind.phoneLocal,
      );

      final decision = engine.selectRoute(request(candidates: [phone]));

      expect(decision.hasRoute, isFalse);
      expect(
        decision.rejected.single.blockers,
        contains(AiroMediaRouteBlockerCode.phoneProxyRequiresConfirmation),
      );
    });

    test('rejects untrusted expired and codec-incompatible candidates', () {
      final untrusted = candidate(
        id: 'untrusted',
        kind: AiroMediaRouteKind.receiverDirect,
        trusted: false,
      );
      final expired = candidate(
        id: 'expired',
        kind: AiroMediaRouteKind.lanDirect,
        expiresAt: now,
      );
      final codecMismatch = candidate(
        id: 'codec',
        kind: AiroMediaRouteKind.serverDirect,
        codecs: const {'h264'},
      );

      final decision = engine.selectRoute(
        request(candidates: [untrusted, expired, codecMismatch]),
      );

      expect(decision.hasRoute, isFalse);
      expect(
        decision.rejected
            .singleWhere((evaluation) => evaluation.candidate == untrusted)
            .blockers,
        contains(AiroMediaRouteBlockerCode.untrusted),
      );
      expect(
        decision.rejected
            .singleWhere((evaluation) => evaluation.candidate == expired)
            .blockers,
        contains(AiroMediaRouteBlockerCode.expired),
      );
      expect(
        decision.rejected
            .singleWhere((evaluation) => evaluation.candidate == codecMismatch)
            .blockers,
        contains(AiroMediaRouteBlockerCode.codecUnsupported),
      );
    });

    test('never selects cloud command route as a media path', () {
      final cloud = candidate(
        id: 'cloud',
        kind: AiroMediaRouteKind.cloudCommandOnly,
        sourceKind: AiroMediaSourceKind.cloudStateOnly,
      );

      final decision = engine.selectRoute(request(candidates: [cloud]));

      expect(decision.hasRoute, isFalse);
      expect(
        decision.rejected.single.blockers,
        contains(AiroMediaRouteBlockerCode.cloudCannotCarryMedia),
      );
    });

    test('decision diagnostics do not expose source handle values', () {
      final direct = candidate(
        id: 'direct',
        kind: AiroMediaRouteKind.receiverDirect,
      );

      final decision = engine.selectRoute(request(candidates: [direct]));

      expect(decision.toString(), isNot(contains('source-direct')));
      expect(direct.toString(), contains('sourceHandle: redacted'));
    });
  });

  group('AiroMediaRouteSourceHandle', () {
    test('rejects unsafe source values at the boundary', () {
      expect(
        AiroMediaRouteSourceHandle.validate('https://example.com/stream.m3u8'),
        AiroMediaRouteSourceHandleRejectionCode.urlValue,
      );
      expect(
        AiroMediaRouteSourceHandle.validate('http://192.168.1.4/live'),
        AiroMediaRouteSourceHandleRejectionCode.urlValue,
      );
      expect(
        AiroMediaRouteSourceHandle.validate('/tmp/live.m3u8'),
        AiroMediaRouteSourceHandleRejectionCode.localPathValue,
      );
      expect(
        AiroMediaRouteSourceHandle.validate('Bearer abc123'),
        AiroMediaRouteSourceHandleRejectionCode.credentialLikeValue,
      );
    });
  });
}
