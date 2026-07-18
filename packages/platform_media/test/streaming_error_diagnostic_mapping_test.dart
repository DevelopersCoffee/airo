import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('mapStreamingErrorToDiagnostic', () {
    test('maps TimeoutException to a retryable network diagnostic', () {
      final diagnostic = mapStreamingErrorToDiagnostic(
        TimeoutException('Load timeout'),
      );

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.networkUnavailable);
      expect(diagnostic.retryEligible, isTrue);
    });

    test('maps a 401/403-bearing message to non-retryable provider auth', () {
      for (final message in [
        'HttpException: 401',
        'PlatformException(VideoError, Exceeds error code, 403 Forbidden)',
      ]) {
        final diagnostic = mapStreamingErrorToDiagnostic(message);
        expect(diagnostic.code, AiroPlaybackDiagnosticCode.providerAuthDenied);
        expect(diagnostic.retryEligible, isFalse);
      }
    });

    test('maps a 404-bearing message to non-retryable provider not-found', () {
      final diagnostic = mapStreamingErrorToDiagnostic(
        'source error: 404 not found',
      );

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.providerNotFound);
      expect(diagnostic.retryEligible, isFalse);
    });

    test('maps a 5xx-bearing message to a retryable provider server error', () {
      final diagnostic = mapStreamingErrorToDiagnostic('upstream 502 error');

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.providerServerError);
      expect(diagnostic.retryEligible, isTrue);
    });

    test('maps a codec/format message to non-retryable codec diagnostic', () {
      final diagnostic = mapStreamingErrorToDiagnostic(
        'MediaCodecVideoRenderer error, unsupported codec',
      );

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.codecUnsupported);
      expect(diagnostic.retryEligible, isFalse);
    });

    test('falls back to an unknown retryable diagnostic for opaque errors', () {
      final diagnostic = mapStreamingErrorToDiagnostic('boom');

      expect(diagnostic.code, AiroPlaybackDiagnosticCode.unknown);
      expect(diagnostic.retryEligible, isTrue);
    });

    test('never includes the raw error text verbatim in technical detail', () {
      final diagnostic = mapStreamingErrorToDiagnostic(
        'http://user:secret@host/live/pw/1.ts?token=abc failed: 403',
      );

      expect(diagnostic.technicalDetail, isNot(contains('secret')));
      expect(diagnostic.technicalDetail, isNot(contains('token=abc')));
    });
  });
}
