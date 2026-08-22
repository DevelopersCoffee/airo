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
    return loadRecords()
        .map((record) => record.document)
        .toList(growable: false);
  }

  List<InstalledPluginRecord> loadRecords() {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final records = <InstalledPluginRecord>[];
      for (final item in decoded.take(maxDocuments)) {
        final record = InstalledPluginRecord.tryParse(item);
        if (record == null) continue;
        if (utf8.encode(record.document).length > maxDocumentBytes) continue;
        records.add(record);
      }
      return records;
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveDocument(String document) async {
    await saveRecord(InstalledPluginRecord.fromDocument(document));
  }

  Future<void> saveRecord(InstalledPluginRecord record) async {
    if (utf8.encode(record.document).length > maxDocumentBytes) {
      throw const FormatException('Skill document exceeds the 256 KB limit.');
    }
    final documents = [
      record,
      ...loadRecords().where((existing) => existing.id != record.id),
    ].take(maxDocuments).toList();
    final encoded = jsonEncode(documents.map((item) => item.toJson()).toList());
    if (utf8.encode(encoded).length > maxStoredBytes) {
      throw const FormatException('Imported skill storage is full.');
    }
    await _preferences.setString(key, encoded);
  }

  Future<void> removeById(String id) async {
    final remaining = loadRecords().where((record) => record.id != id).toList();
    await _preferences.setString(
      key,
      jsonEncode(remaining.map((record) => record.toJson()).toList()),
    );
  }
}

class InstalledPluginRecord {
  const InstalledPluginRecord({
    required this.id,
    required this.version,
    required this.document,
    this.sourceUrl,
    this.origin = 'url',
  });

  final String id;
  final String version;
  final String document;
  final String? sourceUrl;
  final String origin;

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'document': document,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    'origin': origin,
  };

  factory InstalledPluginRecord.fromDocument(
    String document, {
    String? sourceUrl,
    String origin = 'url',
  }) {
    return InstalledPluginRecord(
      id:
          _frontmatterField(document, 'id') ??
          _frontmatterField(document, 'name') ??
          'unknown',
      version: _frontmatterField(document, 'version') ?? '1.0.0',
      document: document,
      sourceUrl: sourceUrl,
      origin: origin,
    );
  }

  static InstalledPluginRecord? tryParse(Object? item) {
    if (item is String) {
      if (item.isEmpty) return null;
      return InstalledPluginRecord.fromDocument(item);
    }
    if (item is Map) {
      final document = item['document'] as String? ?? '';
      if (document.isEmpty) return null;
      return InstalledPluginRecord(
        id:
            item['id'] as String? ??
            _frontmatterField(document, 'id') ??
            'unknown',
        version: item['version'] as String? ?? '1.0.0',
        document: document,
        sourceUrl: item['sourceUrl'] as String?,
        origin: item['origin'] as String? ?? 'url',
      );
    }
    return null;
  }
}

String? _frontmatterField(String document, String key) {
  final match = RegExp(r'^---\s*\n([\s\S]*?)\n---').firstMatch(document);
  final frontmatter = match?.group(1) ?? '';
  final value = RegExp(
    '^$key:\\s*(.+)\$',
    multiLine: true,
  ).firstMatch(frontmatter)?.group(1);
  return value?.trim();
}
