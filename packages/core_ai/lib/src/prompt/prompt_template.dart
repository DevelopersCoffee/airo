/// Versioned prompt template for AI interactions.
///
/// Prompts are versioned to track changes and enable regression detection.
class PromptTemplate {
  /// Unique identifier for the prompt (e.g., 'diet.coach.v1')
  final String id;

  /// Version number
  final int version;

  /// Human-readable name
  final String name;

  /// Description of what this prompt does
  final String description;

  /// The actual prompt template with placeholders
  final String template;

  /// System prompt (optional)
  final String? systemPrompt;

  /// Expected output format (e.g., 'json', 'text', 'markdown')
  final String outputFormat;

  /// Maximum tokens for this prompt
  final int? maxTokens;

  /// Recommended temperature
  final double? temperature;

  /// Tags for categorization
  final List<String> tags;

  const PromptTemplate({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.template,
    this.systemPrompt,
    this.outputFormat = 'text',
    this.maxTokens,
    this.temperature,
    this.tags = const [],
  });

  /// Get the full prompt ID with version (e.g., 'diet.coach.v1')
  String get fullId => '$id.v$version';

  /// Render the template with provided variables.
  String render(Map<String, dynamic> variables) {
    String result = template;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value.toString());
    }
    return result;
  }

  /// Create a copy with updated fields.
  PromptTemplate copyWith({
    String? id,
    int? version,
    String? name,
    String? description,
    String? template,
    String? systemPrompt,
    String? outputFormat,
    int? maxTokens,
    double? temperature,
    List<String>? tags,
  }) {
    return PromptTemplate(
      id: id ?? this.id,
      version: version ?? this.version,
      name: name ?? this.name,
      description: description ?? this.description,
      template: template ?? this.template,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      outputFormat: outputFormat ?? this.outputFormat,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      tags: tags ?? this.tags,
    );
  }

  /// Convert to JSON for storage/logging.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'name': name,
      'description': description,
      'template': template,
      if (systemPrompt != null) 'systemPrompt': systemPrompt,
      'outputFormat': outputFormat,
      if (maxTokens != null) 'maxTokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
      'tags': tags,
    };
  }

  /// Create from JSON.
  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      id: json['id'] as String,
      version: json['version'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      template: json['template'] as String,
      systemPrompt: json['systemPrompt'] as String?,
      outputFormat: json['outputFormat'] as String? ?? 'text',
      maxTokens: json['maxTokens'] as int?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

/// Registry for managing prompt templates.
class PromptRegistry {
  final Map<String, PromptTemplate> _prompts = {};

  /// Register a prompt template.
  void register(PromptTemplate prompt) {
    _prompts[prompt.fullId] = prompt;
  }

  /// Get a prompt by full ID (e.g., 'diet.coach.v1').
  PromptTemplate? get(String fullId) => _prompts[fullId];

  /// Get the latest version of a prompt by base ID.
  PromptTemplate? getLatest(String baseId) {
    final matching = _prompts.values.where((p) => p.id == baseId).toList();
    if (matching.isEmpty) return null;
    matching.sort((a, b) => b.version.compareTo(a.version));
    return matching.first;
  }

  /// Get all prompts with a specific tag.
  List<PromptTemplate> getByTag(String tag) {
    return _prompts.values.where((p) => p.tags.contains(tag)).toList();
  }

  /// Get all registered prompts.
  List<PromptTemplate> getAll() => _prompts.values.toList();

  /// Clear all prompts.
  void clear() => _prompts.clear();
}

