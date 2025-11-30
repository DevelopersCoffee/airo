import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CertificatePinner', () {
    test('creates with pins configuration', () {
      final pinner = CertificatePinner(
        pins: {
          'api.example.com': ['sha256/abc123', 'sha256/def456'],
        },
      );

      expect(pinner.pins, isNotEmpty);
      expect(pinner.pins['api.example.com'], hasLength(2));
    });

    test('allowBadCertificatesInDebug defaults to false', () {
      final pinner = CertificatePinner(pins: {});

      expect(pinner.allowBadCertificatesInDebug, isFalse);
    });

    test('can enable debug mode for bad certificates', () {
      final pinner = CertificatePinner(
        pins: {},
        allowBadCertificatesInDebug: true,
      );

      expect(pinner.allowBadCertificatesInDebug, isTrue);
    });
  });

  group('CertificatePinConfig', () {
    test('production config has empty pins by default', () {
      const config = CertificatePinConfig.production;

      expect(config.pins, isEmpty);
      expect(config.enforceInDebug, isFalse);
      expect(config.rotationPolicy, CertificateRotationPolicy.graceful);
    });

    test('development config has no pins', () {
      const config = CertificatePinConfig.development;

      expect(config.pins, isEmpty);
      expect(config.enforceInDebug, isFalse);
    });

    test('custom config can be created', () {
      const config = CertificatePinConfig(
        pins: {
          'api.test.com': ['sha256/test123'],
        },
        enforceInDebug: true,
        rotationPolicy: CertificateRotationPolicy.immediate,
      );

      expect(config.pins['api.test.com'], contains('sha256/test123'));
      expect(config.enforceInDebug, isTrue);
      expect(config.rotationPolicy, CertificateRotationPolicy.immediate);
    });
  });

  group('CertificatePinningException', () {
    test('creates with message', () {
      const exception = CertificatePinningException('Pin validation failed');

      expect(exception.message, 'Pin validation failed');
      expect(exception.host, isNull);
    });

    test('creates with message and host', () {
      const exception = CertificatePinningException(
        'Pin validation failed',
        host: 'api.example.com',
      );

      expect(exception.message, 'Pin validation failed');
      expect(exception.host, 'api.example.com');
    });

    test('toString includes message', () {
      const exception = CertificatePinningException('Test error');

      expect(exception.toString(), contains('Test error'));
    });

    test('toString includes host when provided', () {
      const exception = CertificatePinningException(
        'Test error',
        host: 'example.com',
      );

      expect(exception.toString(), contains('example.com'));
    });
  });

  group('CertificateRotationPolicy', () {
    test('has all expected values', () {
      expect(CertificateRotationPolicy.values, hasLength(3));
      expect(
        CertificateRotationPolicy.values,
        containsAll([
          CertificateRotationPolicy.graceful,
          CertificateRotationPolicy.immediate,
          CertificateRotationPolicy.requireUpdate,
        ]),
      );
    });
  });
}

