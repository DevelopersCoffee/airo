import '../models/agent_skill.dart';

class SkillManifestFormatException implements FormatException {
  SkillManifestFormatException(this.message, [this.source]);

  @override
  final String message;

  @override
  final dynamic source;

  @override
  int? get offset => null;

  @override
  String toString() => 'SkillManifestFormatException: $message';
}

class SkillManifestParser {
  static final _idPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  static AgentSkill parse(
    String source, {
    SkillSource skillSource = SkillSource.builtIn,
    SkillInstallState installState = SkillInstallState.enabled,
  }) {
    final match = RegExp(
      r'^---\s*\n([\s\S]*?)\n---\s*\n?([\s\S]*)$',
    ).firstMatch(source.trimLeft());
    if (match == null) {
      throw SkillManifestFormatException(
        'SKILL.md must contain YAML frontmatter.',
      );
    }

    final fields = _parseFrontmatter(match.group(1)!);
    final body = match.group(2)!.trim();

    final id = _requiredString(fields, 'id');
    if (!_idPattern.hasMatch(id)) {
      throw SkillManifestFormatException('Skill id must be kebab-case: $id');
    }

    final runtimeKey = _requiredString(fields, 'runtime');
    final runtime = SkillRuntime.fromKey(runtimeKey);
    if (runtime == null) {
      throw SkillManifestFormatException('Unsupported runtime: $runtimeKey');
    }

    final capabilities = _requiredList(fields, 'capabilities').map((key) {
      final capability = SkillCapability.fromKey(key);
      if (capability == null) {
        throw SkillManifestFormatException('Unsupported capability: $key');
      }
      return capability;
    }).toList();

    final tools = _requiredList(fields, 'tools');
    if (body.isEmpty) {
      throw SkillManifestFormatException(
        'Skill instructions body is required.',
      );
    }

    return AgentSkill.fromManifest(
      manifest: AgentSkillManifest(
        id: id,
        name: _requiredString(fields, 'name'),
        description: _requiredString(fields, 'description'),
        version: _requiredString(fields, 'version'),
        author: _requiredString(fields, 'author'),
        runtime: runtime,
        source: skillSource,
        installState: installState,
        capabilities: capabilities,
        tools: tools,
      ),
      instructions: body,
    );
  }

  static Map<String, Object> _parseFrontmatter(String yaml) {
    final fields = <String, Object>{};
    String? currentListKey;

    for (final rawLine in yaml.split('\n')) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;

      final listMatch = RegExp(r'^\s*-\s+(.+)$').firstMatch(line);
      if (listMatch != null) {
        if (currentListKey == null) {
          throw SkillManifestFormatException('List item without a key: $line');
        }
        (fields[currentListKey] as List<String>).add(
          _stripQuotes(listMatch.group(1)!.trim()),
        );
        continue;
      }

      final keyMatch = RegExp(r'^([A-Za-z0-9_-]+):\s*(.*)$').firstMatch(line);
      if (keyMatch == null) {
        throw SkillManifestFormatException('Invalid frontmatter line: $line');
      }

      final key = keyMatch.group(1)!;
      final value = keyMatch.group(2)!.trim();
      if (value.isEmpty) {
        fields[key] = <String>[];
        currentListKey = key;
      } else {
        fields[key] = _stripQuotes(value);
        currentListKey = null;
      }
    }

    return fields;
  }

  static String _requiredString(Map<String, Object> fields, String key) {
    final value = fields[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw SkillManifestFormatException('Missing required field: $key');
  }

  static List<String> _requiredList(Map<String, Object> fields, String key) {
    final value = fields[key];
    if (value is List<String> && value.isNotEmpty) {
      return List.unmodifiable(value);
    }
    throw SkillManifestFormatException('Missing required list: $key');
  }

  static String _stripQuotes(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
