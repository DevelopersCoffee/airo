import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'addon_permission_epoch.dart';
import 'confirmation_token_store.dart';

/// One-use confirmation tokens for LifeTrack writes (§9 framework gate).
class LifeTrackConfirmationTokenService {
  LifeTrackConfirmationTokenService({
    DateTime Function()? now,
    Duration ttl = const Duration(minutes: 15),
    ConfirmationTokenStore? store,
    AddonPermissionEpoch? permissionEpoch,
  }) : _now = now ?? DateTime.now,
       _ttl = ttl,
       _store = store ?? InMemoryConfirmationTokenStore(),
       _permissionEpoch = permissionEpoch ?? AddonPermissionEpoch.instance;

  final DateTime Function() _now;
  final Duration _ttl;
  final ConfirmationTokenStore _store;
  final AddonPermissionEpoch _permissionEpoch;
  final Set<String> _consumed = {};

  Future<String> issue({
    required String destinationTool,
    required Map<String, dynamic> payload,
    String actorId = 'local_user',
  }) async {
    final expiresAt = _now().toUtc().add(_ttl);
    final payloadHash = _payloadHash(payload);
    final record = {
      'schema': 'airo-confirmation-v1',
      'actor_id': actorId,
      'destination_tool': destinationTool,
      'payload_hash': payloadHash,
      'expires_at_ms': expiresAt.millisecondsSinceEpoch,
      'permission_epoch': _permissionEpoch.current,
    };
    final confirmationHash = _confirmationHash(record);
    final token = _randomToken();
    await _store.write(
      token: token,
      record: ConfirmationTokenRecord(
        destinationTool: destinationTool,
        payloadHash: payloadHash,
        confirmationHash: confirmationHash,
        expiresAtMs: expiresAt.millisecondsSinceEpoch,
        permissionEpoch: _permissionEpoch.current,
        actorId: actorId,
      ),
    );
    return token;
  }

  Future<String?> validateAndConsume({
    required String token,
    required String destinationTool,
    required Map<String, dynamic> payload,
    String actorId = 'local_user',
  }) async {
    if (_consumed.contains(token)) return 'confirmation_consumed';
    final issued = await _store.read(token);
    if (issued == null) return 'confirmation_invalid';
    if (issued.destinationTool != destinationTool) {
      return 'confirmation_invalid';
    }
    if (issued.actorId != actorId) {
      return 'confirmation_invalid';
    }
    if (issued.permissionEpoch != _permissionEpoch.current) {
      return 'confirmation_permission_changed';
    }
    if (_now().toUtc().isAfter(
      DateTime.fromMillisecondsSinceEpoch(issued.expiresAtMs, isUtc: true),
    )) {
      await _store.delete(token);
      return 'confirmation_expired';
    }
    final payloadHash = _payloadHash(payload);
    if (issued.payloadHash != payloadHash) {
      return 'confirmation_invalid';
    }
    await _store.delete(token);
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
      'permission_epoch': _permissionEpoch.current,
    };
    return _confirmationHash(record);
  }

  Future<void> invalidateAll() async {
    _consumed.clear();
    await _store.deleteAll();
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
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
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
