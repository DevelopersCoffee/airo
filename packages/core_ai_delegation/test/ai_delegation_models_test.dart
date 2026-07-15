import 'package:core_ai_delegation/core_ai_delegation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo AI search delegation contracts', () {
    AiroAiDelegationRequest request({
      AiroAiPrivacyMode privacyMode = AiroAiPrivacyMode.trustedLocalNetwork,
      Duration maxLatency = const Duration(seconds: 2),
      Set<AiroAiSearchCapability> capabilities = const {
        AiroAiSearchCapability.naturalLanguageSearch,
      },
    }) {
      return AiroAiDelegationRequest(
        requestId: 'search-request-1',
        input: AiroAiSearchInput.redacted('find live sports tonight'),
        requiredCapabilities: capabilities,
        privacyMode: privacyMode,
        maxLatency: maxLatency,
      );
    }

    AiroAiDelegationCandidate candidate({
      String candidateId = 'phone-1',
      AiroAiProcessingLocation location =
          AiroAiProcessingLocation.companionDevice,
      Set<AiroAiSearchCapability> capabilities = const {
        AiroAiSearchCapability.naturalLanguageSearch,
      },
      bool isTrusted = true,
      bool isAvailable = true,
      Duration estimatedLatency = const Duration(milliseconds: 300),
    }) {
      return AiroAiDelegationCandidate(
        candidateId: candidateId,
        displayName: candidateId,
        processingLocation: location,
        capabilities: capabilities,
        isTrusted: isTrusted,
        isAvailable: isAvailable,
        estimatedLatency: estimatedLatency,
      );
    }

    test('redacted input rejects unsafe search values', () {
      expect(
        AiroAiSearchInput.validate(''),
        AiroAiSearchInputRejectionCode.empty,
      );
      expect(
        AiroAiSearchInput.validate('https://example.com/search?q=sports'),
        AiroAiSearchInputRejectionCode.urlValue,
      );
      expect(
        AiroAiSearchInput.validate('/Users/example/query.txt'),
        AiroAiSearchInputRejectionCode.localPathValue,
      );
      expect(
        AiroAiSearchInput.validate('search 192.168.1.10'),
        AiroAiSearchInputRejectionCode.localIpValue,
      );
      expect(
        AiroAiSearchInput.validate('Bearer abc.def'),
        AiroAiSearchInputRejectionCode.credentialLikeValue,
      );
      expect(
        AiroAiSearchInput.redacted('sports tonight').toString(),
        'AiroAiSearchInput(redacted)',
      );
    });

    test('local-only mode accepts on-device candidate only', () {
      const selector = AiroAiDelegationSelector();

      final decision = selector.select(
        request: request(privacyMode: AiroAiPrivacyMode.localOnly),
        candidates: [
          candidate(
            candidateId: 'phone-1',
            location: AiroAiProcessingLocation.companionDevice,
          ),
          candidate(
            candidateId: 'receiver-1',
            location: AiroAiProcessingLocation.onDevice,
            estimatedLatency: const Duration(milliseconds: 900),
          ),
        ],
      );

      expect(decision.accepted, isTrue);
      expect(decision.selectedCandidate?.candidateId, 'receiver-1');
      expect(decision.processingLocation, AiroAiProcessingLocation.onDevice);
    });

    test('trusted local mode prefers companion before cloud', () {
      const selector = AiroAiDelegationSelector();

      final decision = selector.select(
        request: request(),
        candidates: [
          candidate(
            candidateId: 'cloud-1',
            location: AiroAiProcessingLocation.cloudRelay,
            estimatedLatency: const Duration(milliseconds: 100),
          ),
          candidate(
            candidateId: 'phone-1',
            location: AiroAiProcessingLocation.companionDevice,
            estimatedLatency: const Duration(milliseconds: 600),
          ),
        ],
      );

      expect(decision.accepted, isTrue);
      expect(decision.selectedCandidate?.candidateId, 'phone-1');
    });

    test('cloud-allowed mode can use cloud when local candidates fail', () {
      const selector = AiroAiDelegationSelector();

      final decision = selector.select(
        request: request(privacyMode: AiroAiPrivacyMode.cloudAllowed),
        candidates: [
          candidate(
            candidateId: 'phone-1',
            location: AiroAiProcessingLocation.companionDevice,
            isAvailable: false,
          ),
          candidate(
            candidateId: 'cloud-1',
            location: AiroAiProcessingLocation.cloudRelay,
          ),
        ],
      );

      expect(decision.accepted, isTrue);
      expect(decision.selectedCandidate?.candidateId, 'cloud-1');
      expect(decision.processingLocation, AiroAiProcessingLocation.cloudRelay);
    });

    test('returns deterministic blocker codes when no candidate qualifies', () {
      const selector = AiroAiDelegationSelector();

      final decision = selector.select(
        request: request(maxLatency: const Duration(milliseconds: 100)),
        candidates: [
          candidate(candidateId: 'missing-capability', capabilities: const {}),
          candidate(candidateId: 'untrusted', isTrusted: false),
          candidate(candidateId: 'unavailable', isAvailable: false),
          candidate(
            candidateId: 'cloud',
            location: AiroAiProcessingLocation.cloudRelay,
          ),
          candidate(
            candidateId: 'slow',
            estimatedLatency: const Duration(seconds: 4),
          ),
        ],
      );

      expect(decision.accepted, isFalse);
      expect(
        decision.blockers.map((blocker) => blocker.code),
        containsAll(const {
          AiroAiDelegationBlockerCode.missingCapability,
          AiroAiDelegationBlockerCode.untrustedCandidate,
          AiroAiDelegationBlockerCode.unavailableCandidate,
          AiroAiDelegationBlockerCode.privacyModeMismatch,
          AiroAiDelegationBlockerCode.latencyBudgetExceeded,
        }),
      );
    });

    test(
      'request and result string output do not expose search text or refs',
      () {
        final aiRequest = request();
        final result = AiroAiSearchResult(
          requestId: aiRequest.requestId,
          status: AiroAiSearchStatus.accepted,
          processingLocation: AiroAiProcessingLocation.companionDevice,
          confidence: AiroAiConfidenceBucket.high,
          resultRefs: const ['media-ref-1'],
        );

        expect(aiRequest.input.value, 'find live sports tonight');
        expect(
          aiRequest.toString(),
          isNot(contains('find live sports tonight')),
        );
        expect(result.toString(), isNot(contains('media-ref-1')));
        expect(
          result.toString(),
          contains('processingLocation: companion_device'),
        );
      },
    );

    test(
      'no-op provider returns unavailable result without throwing',
      () async {
        const provider = AiroNoOpAiSearchDelegationProvider();

        final result = await provider.search(request());

        expect(result.status, AiroAiSearchStatus.unavailable);
        expect(result.processingLocation, AiroAiProcessingLocation.unavailable);
        expect(result.confidence, AiroAiConfidenceBucket.none);
      },
    );
  });
}
