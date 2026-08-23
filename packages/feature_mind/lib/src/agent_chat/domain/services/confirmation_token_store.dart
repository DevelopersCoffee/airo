import 'dart:convert';

import 'package:core_data/core_data.dart';

/// Persisted confirmation token metadata (§9 authoritative record subset).
class ConfirmationTokenRecord {
  const ConfirmationTokenRecord({
    required this.destinationTool,
    required this.payloadHash,
    required this.confirmationHash,
    required this.expiresAtMs,
    required this.permissionEpoch,
    this.actorId = 'local_user',
  });

  final String destinationTool;
  final String payloadHash;
  final String confirmationHash;
  final int expiresAtMs;
  final int permissionEpoch;
  final String actorId;

  Map<String, dynamic> toJson() => {
    'destination_tool': destinationTool,
    'payload_hash': payloadHash,
    'confirmation_hash': confirmationHash,
    'expires_at_ms': expiresAtMs,
    'permission_epoch': permissionEpoch,
    'actor_id': actorId,
  };

  factory ConfirmationTokenRecord.fromJson(Map<String, dynamic> json) {
    return ConfirmationTokenRecord(
      destinationTool: json['destination_tool'] as String,
      payloadHash: json['payload_hash'] as String,
      confirmationHash: json['confirmation_hash'] as String,
      expiresAtMs: json['expires_at_ms'] as int,
      permissionEpoch: json['permission_epoch'] as int? ?? 0,
      actorId: json['actor_id'] as String? ?? 'local_user',
    );
  }
}

abstract class ConfirmationTokenStore {
  Future<void> write({required String token, required ConfirmationTokenRecord record});

  Future<ConfirmationTokenRecord?> read(String token);

  Future<void> delete(String token);

  Future<void> deleteAll();
}

class InMemoryConfirmationTokenStore implements ConfirmationTokenStore {
  final Map<String, ConfirmationTokenRecord> _records = {};

  @override
  Future<void> write({
    required String token,
    required ConfirmationTokenRecord record,
  }) async {
    _records[token] = record;
  }

  @override
  Future<ConfirmationTokenRecord?> read(String token) => Future.value(_records[token]);

  @override
  Future<void> delete(String token) async {
    _records.remove(token);
  }

  @override
  Future<void> deleteAll() async {
    _records.clear();
  }
}

/// Platform secure store backed token persistence for LifeTrack confirmations.
class SecureConfirmationTokenStore implements ConfirmationTokenStore {
  SecureConfirmationTokenStore({SecureStore? secureStore})
    : _secureStore = secureStore ?? SecureStoreFactory.createSecure();

  static const _keyPrefix = 'airo_mind_confirmation_token_v1_';

  final SecureStore _secureStore;

  @override
  Future<void> write({
    required String token,
    required ConfirmationTokenRecord record,
  }) async {
    await _secureStore.write(
      key: '$_keyPrefix$token',
      value: jsonEncode(record.toJson()),
    );
  }

  @override
  Future<ConfirmationTokenRecord?> read(String token) async {
    final raw = await _secureStore.read(key: '$_keyPrefix$token');
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return ConfirmationTokenRecord.fromJson(decoded);
  }

  @override
  Future<void> delete(String token) async {
    await _secureStore.delete(key: '$_keyPrefix$token');
  }

  @override
  Future<void> deleteAll() async {
    // SecureStore has no prefix scan; consumed tokens are deleted individually.
  }
}
