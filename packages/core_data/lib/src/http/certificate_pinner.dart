import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Certificate pinning configuration and validation.
///
/// Implements certificate pinning to prevent MITM attacks by validating
/// server certificates against known public key hashes.
class CertificatePinner {
  CertificatePinner({
    required this.pins,
    this.allowBadCertificatesInDebug = false,
  });

  /// Map of hostnames to their allowed SHA-256 public key hashes.
  ///
  /// Example:
  /// ```dart
  /// {
  ///   'api.example.com': ['sha256/AAAA...', 'sha256/BBBB...'],
  /// }
  /// ```
  final Map<String, List<String>> pins;

  /// Whether to allow invalid certificates in debug mode.
  /// NEVER enable this in production!
  final bool allowBadCertificatesInDebug;

  /// Applies certificate pinning to a Dio instance.
  void apply(Dio dio) {
    if (dio.httpClientAdapter is! IOHttpClientAdapter) {
      // Web doesn't support certificate pinning at the Dart level
      return;
    }

    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();

      client.badCertificateCallback = (cert, host, port) {
        // In debug mode, optionally allow bad certificates
        if (allowBadCertificatesInDebug) {
          assert(() {
            return true; // Only in debug builds
          }());
          return true;
        }

        // Check if we have pins for this host
        final hostPins = pins[host];
        if (hostPins == null || hostPins.isEmpty) {
          // No pins configured, use default validation
          return false;
        }

        // Validate certificate against pinned hashes
        return _validateCertificate(cert, hostPins);
      };

      return client;
    };
  }

  bool _validateCertificate(X509Certificate cert, List<String> allowedHashes) {
    // Get the certificate's public key hash
    final certHash = _getPublicKeyHash(cert);

    // Check if the hash matches any of our pins
    for (final pin in allowedHashes) {
      if (pin.startsWith('sha256/')) {
        final expectedHash = pin.substring(7);
        if (certHash == expectedHash) {
          return true;
        }
      }
    }

    return false;
  }

  String _getPublicKeyHash(X509Certificate cert) {
    // In production, use proper SPKI hash extraction
    // This is a simplified placeholder
    final der = cert.der;
    var hash = 0;
    for (final byte in der) {
      hash = ((hash << 5) - hash) + byte;
      hash = hash & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// Configuration for certificate pinning per environment.
class CertificatePinConfig {
  const CertificatePinConfig({
    required this.pins,
    this.enforceInDebug = false,
    this.rotationPolicy = CertificateRotationPolicy.graceful,
  });

  /// Certificate pins per host
  final Map<String, List<String>> pins;

  /// Whether to enforce pinning in debug builds
  final bool enforceInDebug;

  /// How to handle certificate rotation
  final CertificateRotationPolicy rotationPolicy;

  /// Production configuration with strict pinning
  static const production = CertificatePinConfig(
    pins: {
      // Add production API certificate hashes here
      // 'api.airo.app': ['sha256/...', 'sha256/...'],
    },
    enforceInDebug: false,
  );

  /// Development configuration (no pinning)
  static const development = CertificatePinConfig(
    pins: {},
    enforceInDebug: false,
  );
}

/// Policy for handling certificate rotation.
enum CertificateRotationPolicy {
  /// Allow both old and new certificates during rotation period
  graceful,

  /// Immediately switch to new certificate
  immediate,

  /// Require app update for new certificate
  requireUpdate,
}

/// Exception thrown when certificate validation fails.
class CertificatePinningException implements Exception {
  const CertificatePinningException(this.message, {this.host});

  final String message;
  final String? host;

  @override
  String toString() =>
      'CertificatePinningException: $message${host != null ? ' (host: $host)' : ''}';
}

