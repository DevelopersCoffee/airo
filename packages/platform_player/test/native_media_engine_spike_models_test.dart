import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('AiroNativeMediaEngineSpikePolicy', () {
    const policy = AiroNativeMediaEngineSpikePolicy();

    AiroNativeMediaEngineSpikeRequest request({
      bool allowExperimentalBackends = false,
      bool requiresHardwareDecode = true,
      bool requiresDecoderFallback = true,
      bool requiresDiagnostics = true,
    }) {
      return AiroNativeMediaEngineSpikeRequest(
        requestId: 'spike-1',
        requiredMediaKinds: const {
          AiroPlaybackMediaKind.hls,
          AiroPlaybackMediaKind.progressive,
          AiroPlaybackMediaKind.live,
        },
        requiredSurfaceModes: const {AiroPlaybackSurfaceMode.texture},
        requiredFeatures: const {
          AiroNativeMediaEngineFeature.subtitleTracks,
          AiroNativeMediaEngineFeature.audioTracks,
          AiroNativeMediaEngineFeature.adaptiveStreaming,
        },
        allowExperimentalBackends: allowExperimentalBackends,
        requiresHardwareDecode: requiresHardwareDecode,
        requiresDecoderFallback: requiresDecoderFallback,
        requiresDiagnostics: requiresDiagnostics,
      );
    }

    AiroNativeMediaEngineCandidate candidate({
      String candidateId = 'media3-spike',
      AiroPlaybackBackendKind backendKind = AiroPlaybackBackendKind.media3,
      AiroNativeMediaEngineMaturity maturity =
          AiroNativeMediaEngineMaturity.candidate,
      Set<AiroPlaybackMediaKind> supportedMediaKinds = const {
        AiroPlaybackMediaKind.hls,
        AiroPlaybackMediaKind.progressive,
        AiroPlaybackMediaKind.live,
      },
      Set<AiroPlaybackSurfaceMode> surfaceModes = const {
        AiroPlaybackSurfaceMode.texture,
        AiroPlaybackSurfaceMode.platformView,
      },
      Set<AiroNativeMediaEngineFeature> features = const {
        AiroNativeMediaEngineFeature.hardwareDecode,
        AiroNativeMediaEngineFeature.softwareDecodeFallback,
        AiroNativeMediaEngineFeature.decoderDiagnostics,
        AiroNativeMediaEngineFeature.bufferDiagnostics,
        AiroNativeMediaEngineFeature.subtitleTracks,
        AiroNativeMediaEngineFeature.audioTracks,
        AiroNativeMediaEngineFeature.adaptiveStreaming,
      },
    }) {
      return AiroNativeMediaEngineCandidate(
        candidateId: candidateId,
        backendKind: backendKind,
        maturity: maturity,
        supportedMediaKinds: supportedMediaKinds,
        surfaceModes: surfaceModes,
        features: features,
      );
    }

    test(
      'accepts candidate that meets baseline native engine requirements',
      () {
        final result = policy.evaluate(
          candidate: candidate(),
          request: request(),
        );

        expect(result.accepted, isTrue);
      },
    );

    test('rejects unsupported media kind and missing surface mode', () {
      final result = policy.evaluate(
        candidate: candidate(
          supportedMediaKinds: const {AiroPlaybackMediaKind.hls},
          surfaceModes: const {AiroPlaybackSurfaceMode.externalReceiver},
        ),
        request: request(),
      );

      expect(
        result.blockers,
        contains(AiroNativeMediaEngineBlockerCode.unsupportedMediaKind),
      );
      expect(
        result.blockers,
        contains(AiroNativeMediaEngineBlockerCode.missingSurfaceMode),
      );
    });

    test('rejects missing diagnostics hardware decode and fallback', () {
      final result = policy.evaluate(
        candidate: candidate(
          features: const {
            AiroNativeMediaEngineFeature.subtitleTracks,
            AiroNativeMediaEngineFeature.audioTracks,
            AiroNativeMediaEngineFeature.adaptiveStreaming,
          },
        ),
        request: request(),
      );

      expect(
        result.blockers,
        contains(AiroNativeMediaEngineBlockerCode.missingDiagnostics),
      );
      expect(
        result.blockers,
        contains(AiroNativeMediaEngineBlockerCode.missingHardwareDecode),
      );
      expect(
        result.blockers,
        contains(AiroNativeMediaEngineBlockerCode.missingDecoderFallback),
      );
    });

    test('rejects experimental or blocked backends by policy', () {
      final experimental = policy.evaluate(
        candidate: candidate(
          maturity: AiroNativeMediaEngineMaturity.experimental,
        ),
        request: request(),
      );
      final allowedExperimental = policy.evaluate(
        candidate: candidate(
          maturity: AiroNativeMediaEngineMaturity.experimental,
        ),
        request: request(allowExperimentalBackends: true),
      );
      final blocked = policy.evaluate(
        candidate: candidate(maturity: AiroNativeMediaEngineMaturity.blocked),
        request: request(allowExperimentalBackends: true),
      );

      expect(
        experimental.blockers,
        contains(
          AiroNativeMediaEngineBlockerCode.experimentalBackendNotAllowed,
        ),
      );
      expect(allowedExperimental.accepted, isTrue);
      expect(
        blocked.blockers,
        contains(AiroNativeMediaEngineBlockerCode.backendBlocked),
      );
    });

    test('diagnostics expose stable ids without raw media references', () {
      final rendered = candidate().toString();

      expect(rendered, contains('media3-spike'));
      expect(rendered, contains('media3'));
      expect(rendered, isNot(contains('http')));
      expect(rendered, isNot(contains('/Users/')));
      expect(rendered, isNot(contains('credential')));
    });
  });

  group('AiroNativeMediaEngineCandidateRegistry adapters', () {
    final candidate = AiroNativeMediaEngineCandidate(
      candidateId: 'media3-spike',
      backendKind: AiroPlaybackBackendKind.media3,
      maturity: AiroNativeMediaEngineMaturity.candidate,
      supportedMediaKinds: const {AiroPlaybackMediaKind.hls},
      surfaceModes: const {AiroPlaybackSurfaceMode.texture},
      features: const {AiroNativeMediaEngineFeature.hardwareDecode},
    );

    test('no-op registry returns no candidates', () {
      const registry = AiroNoOpNativeMediaEngineCandidateRegistry();

      expect(registry.candidates(), isEmpty);
    });

    test('fake registry returns deterministic candidates', () {
      final registry = AiroFakeNativeMediaEngineCandidateRegistry(
        candidates: [candidate],
      );

      expect(registry.candidates().single.candidateId, 'media3-spike');
    });
  });
}
