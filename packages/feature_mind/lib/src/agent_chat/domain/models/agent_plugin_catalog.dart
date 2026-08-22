import 'dart:convert';

import '../../../runtime/models/capability_models.dart';
import 'agent_skill.dart';

class AgentPluginCatalogEntry {
  const AgentPluginCatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.family,
    required this.safetyClass,
    required this.author,
    required this.url,
  });

  final String id;
  final String name;
  final String description;
  final String version;
  final AgentPersonaFamily family;
  final CapabilitySafetyClass safetyClass;
  final String author;
  final String url;
}

class AgentPluginCatalog {
  const AgentPluginCatalog(this.entries);

  final List<AgentPluginCatalogEntry> entries;

  static const schema = 1;
  static const maxCatalogBytes = 64 * 1024;

  AgentPluginCatalogEntry? getById(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  static AgentPluginCatalog parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Plugin catalog must be a JSON object.');
    }
    final plugins = decoded['plugins'];
    if (plugins is! List) {
      throw const FormatException('Plugin catalog is missing plugins.');
    }
    final entries = <AgentPluginCatalogEntry>[];
    for (final raw in plugins) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final id = map['id'] as String? ?? '';
      final name = map['name'] as String? ?? '';
      final description = map['description'] as String? ?? '';
      final url = map['url'] as String? ?? '';
      if (id.isEmpty || name.isEmpty || description.isEmpty || url.isEmpty) {
        continue;
      }
      if (!url.startsWith('https://')) {
        throw FormatException('Plugin $id must use an HTTPS URL.');
      }
      entries.add(
        AgentPluginCatalogEntry(
          id: id,
          name: name,
          description: description,
          version: map['version'] as String? ?? '1.0.0',
          family:
              AgentPersonaFamily.fromKey(map['family'] as String? ?? '') ??
              AgentPersonaFamily.general,
          safetyClass: _safetyClass(
            map['safety_class'] as String? ?? 'general',
          ),
          author: map['author'] as String? ?? 'Airo',
          url: url,
        ),
      );
    }
    return AgentPluginCatalog(List.unmodifiable(entries));
  }

  static CapabilitySafetyClass _safetyClass(String key) {
    for (final value in CapabilitySafetyClass.values) {
      if (value.name == key) return value;
    }
    return CapabilitySafetyClass.general;
  }
}
