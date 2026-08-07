import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores imported SKILL.md documents separately from built-in skill state.
/// The raw document is retained so future manifest migrations can re-parse it.
class RemoteAgentSkillStore {
  RemoteAgentSkillStore(this._preferences);

  static const key = 'agent_skills.remote_documents.v1';
  static const maxDocuments = 32;
  static const maxDocumentBytes = 256 * 1024;
  static const maxStoredBytes = 1024 * 1024;

  final SharedPreferences _preferences;

  List<String> loadDocuments() {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .where((document) => utf8.encode(document).length <= maxDocumentBytes)
          .take(maxDocuments)
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveDocument(String document) async {
    if (utf8.encode(document).length > maxDocumentBytes) {
      throw const FormatException('Skill document exceeds the 256 KB limit.');
    }
    final documents = [
      document,
      ...loadDocuments().where((existing) => existing != document),
    ].take(maxDocuments).toList();
    final encoded = jsonEncode(documents);
    if (utf8.encode(encoded).length > maxStoredBytes) {
      throw const FormatException('Imported skill storage is full.');
    }
    await _preferences.setString(key, encoded);
  }

  Future<void> removeById(String id) async {
    final remaining = loadDocuments().where((document) {
      final match = RegExp(r'^---\s*\n([\s\S]*?)\n---').firstMatch(document);
      return !((match?.group(1) ?? '').contains('id: $id'));
    }).toList();
    await _preferences.setString(key, jsonEncode(remaining));
  }
}
