import 'package:core_media_routing/core_media_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroMediaRouteScoringPolicy', () {
    const routingEngine = AiroDeterministicMediaRoutingEngine();
    const scoringPolicy = AiroMediaRouteScoringPolicy();
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroMediaRouteCandidate candidate({
      required String id,
      required AiroMediaRouteKind kind,
      bool available = true,
      bool trusted = true,
      Set<String> codecs = const {'h264', 'aac'},
    }) {
      return AiroMediaRouteCandidate(
        candidateId: id,
        kind: kind,
        sourceKind: kind.isPhoneProxy
            ? AiroMediaSourceKind.phoneLocal
            : AiroMediaSourceKind.iptv,
        sourceHandle: AiroMediaRouteSourceHandle.redacted('source-$id'),
        playbackNodeId: 'receiver-1',
        sourceNodeId: 'source-1',
        supportedCodecs: codecs,
        isAvailable: available,
        isTrusted: trusted,
      );
    }

    AiroMediaRouteDecision baseDecision({
      required List<AiroMediaRouteCandidate> candidates,
      bool userConfirmedPhoneProxy = false,
    }) {
      return routingEngine.selectRoute(
        AiroMediaRouteRequest(
          requestId: 'request-1',
          intent: AiroMediaRouteIntent.play,
          requestedAt: now,
          candidates: candidates,
          requiredCodecs: const {'h264', 'aac'},
          userConfirmedPhoneProxy: userConfirmedPhoneProxy,
        ),
      );
    }

    test('higher health and bandwidth direct route wins', () {
      final weak = candidate(
        id: 'direct-b',
        kind: AiroMediaRouteKind.lanDirect,
      );
      final strong = candidate(
        id: 'direct-a',
        kind: AiroMediaRouteKind.lanDirect,
      );
      final decision = scoringPolicy.scoreDecision(
        decision: baseDecision(candidates: [weak, strong]),
        signalsByCandidateId: const {
          'direct-a': AiroMediaRouteScoreSignals(
            health: 95,
            bandwidth: 95,
            reliability: 90,
          ),
          'direct-b': AiroMediaRouteScoreSignals(
            health: 20,
            bandwidth: 20,
            reliability: 30,
          ),
        },
        generatedAt: now,
      );

      expect(decision.selected?.candidateId, 'direct-a');
      expect(
        decision.selected!.reasonCodes,
        contains(AiroMediaRouteDecisionReasonCode.selectedHighestScore),
      );
    });

    test('phone proxy remains lower ranked despite strong signals', () {
      final direct = candidate(
        id: 'direct',
        kind: AiroMediaRouteKind.receiverDirect,
      );
      final phone = candidate(id: 'phone', kind: AiroMediaRouteKind.phoneProxy);
      final decision = scoringPolicy.scoreDecision(
        decision: baseDecision(
          candidates: [phone, direct],
          userConfirmedPhoneProxy: true,
        ),
        signalsByCandidateId: const {
          'direct': AiroMediaRouteScoreSignals(
            health: 55,
            bandwidth: 55,
            reliability: 55,
          ),
          'phone': AiroMediaRouteScoreSignals(
            health: 100,
            bandwidth: 100,
            reliability: 100,
          ),
        },
        generatedAt: now,
      );

      expect(decision.selected?.candidateId, 'direct');
      final phoneScore = decision.scores.singleWhere(
        (score) => score.candidateId == 'phone',
      );
      expect(
        phoneScore.reasonCodes,
        contains(AiroMediaRouteDecisionReasonCode.phoneProxyPenalized),
      );
      expect(
        phoneScore.components.map((component) => component.componentId),
        contains(AiroMediaRouteScoreComponentId.phoneProxyPenalty),
      );
    });

    test('battery and thermal penalties lower phone route score', () {
      final phone = candidate(id: 'phone', kind: AiroMediaRouteKind.phoneProxy);
      final decision = scoringPolicy.scoreDecision(
        decision: baseDecision(
          candidates: [phone],
          userConfirmedPhoneProxy: true,
        ),
        signalsByCandidateId: const {
          'phone': AiroMediaRouteScoreSignals(
            health: 90,
            bandwidth: 90,
            battery: 5,
            thermal: 10,
          ),
        },
        generatedAt: now,
      );

      expect(decision.selected?.candidateId, 'phone');
      expect(
        decision.selected!.reasonCodes,
        contains(AiroMediaRouteDecisionReasonCode.lowBatteryPenalty),
      );
      expect(
        decision.selected!.reasonCodes,
        contains(AiroMediaRouteDecisionReasonCode.thermalPenalty),
      );
    });

    test('blocked candidates are logged with blocker codes only', () {
      final blocked = candidate(
        id: 'blocked',
        kind: AiroMediaRouteKind.receiverDirect,
        trusted: false,
      );
      final decision = scoringPolicy.scoreDecision(
        decision: baseDecision(candidates: [blocked]),
        signalsByCandidateId: const {},
        generatedAt: now,
      );

      expect(decision.hasRoute, isFalse);
      final entry = decision.decisionLog.entries.single;
      expect(entry.eligible, isFalse);
      expect(entry.blockers, contains(AiroMediaRouteBlockerCode.untrusted));
      expect(
        entry.reasonCodes,
        contains(AiroMediaRouteDecisionReasonCode.rejectedByPreflight),
      );
      expect(
        entry.reasonCodes,
        contains(AiroMediaRouteDecisionReasonCode.noEligibleRoute),
      );
    });

    test('tie breaking is stable by candidate id', () {
      final b = candidate(id: 'b-route', kind: AiroMediaRouteKind.lanDirect);
      final a = candidate(id: 'a-route', kind: AiroMediaRouteKind.lanDirect);
      final decision = scoringPolicy.scoreDecision(
        decision: baseDecision(candidates: [b, a]),
        signalsByCandidateId: const {
          'a-route': AiroMediaRouteScoreSignals(),
          'b-route': AiroMediaRouteScoreSignals(),
        },
        generatedAt: now,
      );

      expect(decision.selected?.candidateId, 'a-route');
      expect(
        decision.selected!.reasonCodes,
        contains(AiroMediaRouteDecisionReasonCode.selectedByStableTieBreak),
      );
    });

    test('decision logs do not expose source handle values', () {
      final route = candidate(id: 'direct', kind: AiroMediaRouteKind.lanDirect);
      final decision = scoringPolicy.scoreDecision(
        decision: baseDecision(candidates: [route]),
        signalsByCandidateId: const {},
        generatedAt: now,
      );

      expect(decision.decisionLog.toString(), isNot(contains('source-direct')));
      expect(decision.decisionLog.toString(), contains('candidateId: direct'));
      expect(decision.decisionLog.toString(), contains('totalScore'));
    });
  });
}
