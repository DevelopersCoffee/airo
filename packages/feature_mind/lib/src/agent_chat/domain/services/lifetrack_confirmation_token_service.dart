import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// One-use confirmation tokens for LifeTrack writes (§9 framework gate).
class LifeTrackConfirmationTokenService {
  LifeTrackConfirmationTokenService({
    DateTime Function()? now,
    Duration ttl = const Duration(minutes: 15),
  }) : _now = now ?? DateTime.now,
       _ttl = ttl;

  final DateTime Function() _now;
  final Duration _ttl;
  final Map<String, _IssuedToken> _issued = {};
  final Set<String> _consumed = {};

  String issue({
    required String destinationTool,
    required Map<String, dynamic> payload,
    String actorId = 'local_user',
  }) {
    final expiresAt = _now().toUtc().add(_ttl);
    final payloadHash = _payloadHash(payload);
    final record = {
      'schema': 'airo-confirmation-v1',
      'actor_id': actorId,
      'destination_tool': destinationTool,
      'payload_hash': payloadHash,
      'expires_at_ms': expiresAt.millisecondsSinceEpoch,
    };
    final confirmationHash = _confirmationHash(record);
    final token = _randomToken();
    _issued[token] = _IssuedToken(
      destinationTool: destinationTool,
      payloadHash: payloadHash,
      confirmationHash: confirmationHash,
      expiresAt: expiresAt,
    );
    return token;
  }

  String? validateAndConsume({
    required String token,
    required String destinationTool,
    required Map<String, dynamic> payload,
  }) {
    if (_consumed.contains(token)) return 'confirmation_consumed';
    final issued = _issued[token];
    if (issued == null) return 'confirmation_invalid';
    if (issued.destinationTool != destinationTool) {
      return 'confirmation_invalid';
    }
    if (_now().toUtc().isAfter(issued.expiresAt)) {
      _issued.remove(token);
      return 'confirmation_expired';
    }
    if (issued.payloadHash != _payloadHash(payload)) {
      return 'confirmation_invalid';
    }
    _issued.remove(token);
    _consumed.add(token);
    return null;
  }

  String confirmationHashFor({
    required String destinationTool,
    required Map<String, dynamic> payload,
    String actorId = 'local_user',
  }) {
    final record = {
      'schema': 'airo-confirmation-v1',
      'actor_id': actorId,
      'destination_tool': destinationTool,
      'payload_hash': _payloadHash(payload),
    };
    return _confirmationHash(record);
  }

  static String _payloadHash(Map<String, dynamic> payload) =>
      sha256.convert(utf8.encode(_canonicalJson(payload))).toString();

  static String _confirmationHash(Map<String, dynamic> record) {
    final canonical = _canonicalJson(record);
    final bytes = utf8.encode('airo-confirmation-v1\n$canonical');
    return sha256.convert(bytes).toString();
  }

  static String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()
        ..sort();
      final ordered = <String, Object?>{};
      for (final key in keys) {
        ordered[key] = _canonicalize(value[key]);
      }
      return jsonEncode(ordered);
    }
    if (value is List) {
      return jsonEncode(value.map(_canonicalize).toList());
    }
    return jsonEncode(value);
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      final ordered = <String, Object?>{};
      for (final key in keys) {
        ordered[key] = _canonicalize(value[key]);
      }
      return ordered;
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }

  static String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

class _IssuedToken {
  const _IssuedToken({
    required this.destinationTool,
    required this.payloadHash,
    required this.confirmationHash,
    required this.expiresAt,
  });

  final String destinationTool;
  final String payloadHash;
  final String confirmationHash;
  final DateTime expiresAt;
}
