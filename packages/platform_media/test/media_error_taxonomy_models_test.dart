import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';

void main() {
  group('AiroDefaultMediaErrorClassifier', () {
    const classifier = AiroDefaultMediaErrorClassifier();

    test('classifies network failures as retryable warning errors', () {
      final descriptor = classifier.classify(
        AiroMediaErrorInput(
          code: AiroMediaErrorCode.networkTimeout,
          contexts: [
            AiroMediaErrorContext(
              kind: AiroMediaErrorContextKind.session,
              ref: AiroMediaErrorSafeValue.redacted('session-1'),
            ),
          ],
          diagnosticCodes: [AiroMediaDiagnosticCode.stable('dns_timeout')],
          diagnosticHandle: AiroMediaDiagnosticHandle.redacted(
            'local-diagnostic-1',
          ),
        ),
      );

      expect(descriptor.category, AiroMediaErrorCategory.network);
      expect(descriptor.severity, AiroMediaErrorSeverity.warning);
      expect(descriptor.retryability, AiroMediaErrorRetryability.afterBackoff);
      expect(descriptor.retryable, isTrue);
      expect(descriptor.canRetryAutomatically, isTrue);
      expect(descriptor.requiresUserAction, isFalse);
      expect(descriptor.userMessageKey.value, 'media.network.timeout');
    });

    test(
      'classifies auth and source refresh errors as user-action retries',
      () {
        final auth = classifier.classify(
          AiroMediaErrorInput(code: AiroMediaErrorCode.authenticationRequired),
        );
        final expired = classifier.classify(
          AiroMediaErrorInput(code: AiroMediaErrorCode.sourceExpired),
        );

        expect(auth.category, AiroMediaErrorCategory.authentication);
        expect(auth.requiresUserAction, isTrue);
        expect(auth.userMessageKey.value, 'media.auth.required');
        expect(
          expired.retryability,
          AiroMediaErrorRetryability.afterSourceRefresh,
        );
        expect(expired.requiresUserAction, isTrue);
        expect(expired.userMessageKey.value, 'media.source.expired');
      },
    );

    test('classifies decoder and playback failures for fallback decisions', () {
      final decoder = classifier.classify(
        AiroMediaErrorInput(code: AiroMediaErrorCode.decoderFailed),
      );
      final startup = classifier.classify(
        AiroMediaErrorInput(code: AiroMediaErrorCode.playbackStartupFailed),
      );

      expect(decoder.category, AiroMediaErrorCategory.decoder);
      expect(decoder.severity, AiroMediaErrorSeverity.critical);
      expect(decoder.retryability, AiroMediaErrorRetryability.immediate);
      expect(startup.category, AiroMediaErrorCategory.playback);
      expect(startup.canRetryAutomatically, isTrue);
    });

    test('keeps analytics rejection local and non-retryable', () {
      final descriptor = classifier.classify(
        AiroMediaErrorInput(code: AiroMediaErrorCode.analyticsRejected),
      );

      expect(descriptor.category, AiroMediaErrorCategory.analytics);
      expect(descriptor.severity, AiroMediaErrorSeverity.info);
      expect(descriptor.retryability, AiroMediaErrorRetryability.never);
      expect(descriptor.retryable, isFalse);
      expect(descriptor.userMessageKey.value, 'media.analytics.rejected');
    });
  });

  group('Airo media error redaction', () {
    test('safe context and diagnostic handles reject raw sensitive values', () {
      expect(
        () => AiroMediaErrorSafeValue.redacted(
          'https://provider.example/live.m3u8',
        ),
        throwsArgumentError,
      );
      expect(
        () => AiroMediaErrorSafeValue.redacted('/Users/me/movie.mp4'),
        throwsArgumentError,
      );
      expect(
        () => AiroMediaErrorSafeValue.redacted('192.168.1.20/media.m3u8'),
        throwsArgumentError,
      );
      expect(
        () => AiroMediaDiagnosticHandle.redacted('Bearer abc123'),
        throwsArgumentError,
      );
      expect(
        () => AiroMediaDiagnosticCode.stable('https://example.com/detail'),
        throwsArgumentError,
      );
      expect(
        () => AiroMediaDiagnosticCode.stable('Decoder failed'),
        throwsArgumentError,
      );
    });

    test('user message keys are stable and not raw user copy', () {
      expect(
        AiroMediaUserMessageKey.stable('media.network.timeout').value,
        'media.network.timeout',
      );
      expect(
        () => AiroMediaUserMessageKey.stable('Network timed out'),
        throwsArgumentError,
      );
      expect(
        () => AiroMediaUserMessageKey.stable('https://example.com/error'),
        throwsArgumentError,
      );
    });

    test('string output redacts context and diagnostic handle values', () {
      final descriptor = const AiroDefaultMediaErrorClassifier().classify(
        AiroMediaErrorInput(
          code: AiroMediaErrorCode.routeUnavailable,
          contexts: [
            AiroMediaErrorContext(
              kind: AiroMediaErrorContextKind.route,
              ref: AiroMediaErrorSafeValue.redacted('route-primary'),
            ),
          ],
          diagnosticHandle: AiroMediaDiagnosticHandle.redacted('diag-1'),
        ),
      );

      final rendered = descriptor.toString();

      expect(rendered, contains('route_unavailable'));
      expect(rendered, contains('diagnosticHandle: redacted'));
      expect(rendered, isNot(contains('route-primary')));
      expect(rendered, isNot(contains('diag-1')));
      expect(rendered, isNot(contains('http')));
      expect(rendered, isNot(contains('/Users/')));
    });
  });

  group('AiroMediaErrorClassifier adapters', () {
    test('no-op classifier returns safe unknown descriptor', () {
      const classifier = AiroNoOpMediaErrorClassifier();

      final descriptor = classifier.classify(
        AiroMediaErrorInput(code: AiroMediaErrorCode.decoderFailed),
      );

      expect(descriptor.code, AiroMediaErrorCode.unknown);
      expect(descriptor.category, AiroMediaErrorCategory.unknown);
      expect(descriptor.userMessageKey.value, 'media.error.unknown');
      expect(descriptor.diagnosticCodes.single.value, 'noop_classifier');
    });

    test('fake classifier returns deterministic descriptors', () {
      final expected = AiroMediaErrorDescriptor(
        code: AiroMediaErrorCode.storageFull,
        category: AiroMediaErrorCategory.storage,
        severity: AiroMediaErrorSeverity.critical,
        retryability: AiroMediaErrorRetryability.afterUserAction,
        userMessageKey: AiroMediaUserMessageKey.stable('media.storage.full'),
      );
      final classifier = AiroFakeMediaErrorClassifier(
        descriptors: {AiroMediaErrorCode.storageFull: expected},
      );

      final descriptor = classifier.classify(
        AiroMediaErrorInput(code: AiroMediaErrorCode.storageFull),
      );

      expect(descriptor, expected);
    });
  });
}
