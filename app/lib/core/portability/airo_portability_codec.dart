import 'dart:convert';

import 'package:core_workers/core_workers.dart';

/// Worker-backed serialization for Airo Mind portability payloads.
///
/// Keeping this boundary outside presentation code prevents large chat-history
/// payloads from blocking the UI isolate and gives the release policy a single
/// reusable place to audit serialization behavior.
class AiroPortabilityCodec {
  const AiroPortabilityCodec._();

  static Future<List<Object?>?> decodeChatHistory(String? encoded) {
    final value = encoded;
    if (value == null || value.trim().isEmpty) return Future.value(null);
    return runOffMain(() {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map) return null;
        final entries = decoded['entries'];
        return entries is List ? List<Object?>.from(entries) : null;
      } on Object {
        return null;
      }
    });
  }

  static Future<String> encodePayload(Map<String, Object?> payload) {
    return runOffMain(() => jsonEncode(payload));
  }

  static Future<String> encodeChatHistory(
    List<Object?> entries, {
    required int schemaVersion,
  }) {
    return runOffMain(
      () => jsonEncode({'schemaVersion': schemaVersion, 'entries': entries}),
    );
  }
}
