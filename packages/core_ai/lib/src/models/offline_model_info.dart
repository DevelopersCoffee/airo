import 'package:meta/meta.dart';

import '../provider/ai_provider.dart';
import 'model_credibility.dart';

/// Quantization level for GGUF models.
///
/// Lower quantization = smaller file size but lower quality.
/// Higher quantization = larger file size but better quality.
enum ModelQuantization {
  /// 2-bit quantization (smallest, lowest quality)
  q2('Q2', 2, 'Smallest size, lowest quality'),

  /// 3-bit quantization
  q3('Q3', 3, 'Very small, low quality'),

  /// 4-bit quantization (common for mobile)
  q4('Q4', 4, 'Small size, good quality balance'),

  /// 5-bit quantization
  q5('Q5', 5, 'Medium size, good quality'),

  /// 6-bit quantization
  q6('Q6', 6, 'Larger size, high quality'),

  /// 8-bit quantization
  q8('Q8', 8, 'Large size, very high quality'),

  /// Full precision (FP16)
  fp16('FP16', 16, 'Full precision, largest size'),

  /// Unknown quantization
  unknown('Unknown', 0, 'Unknown quantization level');

  const ModelQuantization(this.displayName, this.bits, this.description);

  final String displayName;
  final int bits;
  final String description;

  /// Estimated memory multiplier compared to model parameters.
  double get memoryMultiplier => bits / 16.0;
}

/// Model family/architecture type.
enum ModelFamily {
  gemma('Gemma', 'Google Gemma open models'),
  llama('Llama', 'Meta Llama models'),
  phi('Phi', 'Microsoft Phi small language models'),
  mistral('Mistral', 'Mistral AI models'),
  qwen('Qwen', 'Alibaba Qwen models'),
  stableLM('StableLM', 'Stability AI models'),
  falcon('Falcon', 'TII Falcon models'),
  mpt('MPT', 'MosaicML MPT models'),
  other('Other', 'Other model architectures');

  const ModelFamily(this.displayName, this.description);

  final String displayName;
  final String description;
}

/// Information about an offline LLM model available in the registry.
///
/// Contains all metadata needed to display, filter, and load a model.
/// Follows patterns from the reference implementation.
@immutable
class OfflineModelInfo {
  const OfflineModelInfo({
    required this.id,
    required this.name,
    required this.family,
    required this.fileSizeBytes,
    this.filePath,
    this.downloadUrl,
    this.quantization = ModelQuantization.q4,
    this.parameterCount,
    this.contextLength = 2048,
    this.supportsVision = false,
    this.supportsFunctionCalling = false,
    this.languages = const ['en'],
    this.credibility = ModelCredibility.community,
    this.provider = AIProvider.gguf,
    this.description,
    this.version,
    this.author,
    this.license,
    this.huggingFaceId,
    this.sha256,
    this.tags = const [],
    this.minMemoryBytes,
    this.recommendedMemoryBytes,
  });

  /// Unique identifier for this model.
  final String id;

  /// Human-readable model name.
  final String name;

  /// Model family/architecture.
  final ModelFamily family;

  /// Model file size in bytes.
  final int fileSizeBytes;

  /// Local file path (if downloaded).
  final String? filePath;

  /// URL to download the model.
  final String? downloadUrl;

  /// Quantization level.
  final ModelQuantization quantization;

  /// Number of parameters (e.g., 2B, 7B, 13B).
  final int? parameterCount;

  /// Maximum context length in tokens.
  final int contextLength;

  /// Whether the model supports vision/image input.
  final bool supportsVision;

  /// Whether the model supports function calling.
  final bool supportsFunctionCalling;

  /// Supported languages (ISO 639-1 codes).
  final List<String> languages;

  /// Credibility level of this model.
  final ModelCredibility credibility;

  /// AI provider type.
  final AIProvider provider;

  /// Model description.
  final String? description;

  /// Model version string.
  final String? version;

  /// Model author/organization.
  final String? author;

  /// License type (e.g., 'Apache-2.0', 'MIT', 'Llama 2 Community').
  final String? license;

  /// HuggingFace model ID (e.g., 'google/gemma-2b-it-GGUF').
  final String? huggingFaceId;

  /// SHA256 hash of the model file for verification.
  final String? sha256;

  /// Tags for filtering and categorization.
  final List<String> tags;

  /// Minimum memory required to load (bytes).
  final int? minMemoryBytes;

  /// Recommended memory for optimal performance (bytes).
  final int? recommendedMemoryBytes;

  /// Whether the model is downloaded and available locally.
  bool get isDownloaded => filePath != null;

  /// File size in megabytes.
  double get fileSizeMB => fileSizeBytes / (1024 * 1024);

  /// File size in gigabytes.
  double get fileSizeGB => fileSizeBytes / (1024 * 1024 * 1024);

  /// Human-readable file size string.
  String get fileSizeDisplay {
    if (fileSizeGB >= 1.0) {
      return '${fileSizeGB.toStringAsFixed(1)} GB';
    }
    return '${fileSizeMB.toStringAsFixed(0)} MB';
  }

  /// Human-readable parameter count (e.g., "2B", "7B").
  String? get parameterCountDisplay {
    if (parameterCount == null) return null;
    if (parameterCount! >= 1000000000) {
      return '${(parameterCount! / 1000000000).toStringAsFixed(1)}B';
    }
    if (parameterCount! >= 1000000) {
      return '${(parameterCount! / 1000000).toStringAsFixed(0)}M';
    }
    return parameterCount.toString();
  }

  /// Estimated minimum memory based on file size and quantization.
  int get estimatedMinMemoryBytes {
    if (minMemoryBytes != null) return minMemoryBytes!;
    // Rough estimate: model file + 20% overhead for KV cache
    return (fileSizeBytes * 1.2).round();
  }

  /// Estimated recommended memory based on file size and quantization.
  int get estimatedRecommendedMemoryBytes {
    if (recommendedMemoryBytes != null) return recommendedMemoryBytes!;
    // Rough estimate: model file + 50% overhead for comfortable operation
    return (fileSizeBytes * 1.5).round();
  }

  /// Creates a copy with modified fields.
  OfflineModelInfo copyWith({
    String? id,
    String? name,
    ModelFamily? family,
    int? fileSizeBytes,
    String? filePath,
    String? downloadUrl,
    ModelQuantization? quantization,
    int? parameterCount,
    int? contextLength,
    bool? supportsVision,
    bool? supportsFunctionCalling,
    List<String>? languages,
    ModelCredibility? credibility,
    AIProvider? provider,
    String? description,
    String? version,
    String? author,
    String? license,
    String? huggingFaceId,
    String? sha256,
    List<String>? tags,
    int? minMemoryBytes,
    int? recommendedMemoryBytes,
  }) {
    return OfflineModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      family: family ?? this.family,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      filePath: filePath ?? this.filePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      quantization: quantization ?? this.quantization,
      parameterCount: parameterCount ?? this.parameterCount,
      contextLength: contextLength ?? this.contextLength,
      supportsVision: supportsVision ?? this.supportsVision,
      supportsFunctionCalling:
          supportsFunctionCalling ?? this.supportsFunctionCalling,
      languages: languages ?? this.languages,
      credibility: credibility ?? this.credibility,
      provider: provider ?? this.provider,
      description: description ?? this.description,
      version: version ?? this.version,
      author: author ?? this.author,
      license: license ?? this.license,
      huggingFaceId: huggingFaceId ?? this.huggingFaceId,
      sha256: sha256 ?? this.sha256,
      tags: tags ?? this.tags,
      minMemoryBytes: minMemoryBytes ?? this.minMemoryBytes,
      recommendedMemoryBytes:
          recommendedMemoryBytes ?? this.recommendedMemoryBytes,
    );
  }

  /// Converts to JSON map for persistence.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'family': family.name,
    'fileSizeBytes': fileSizeBytes,
    'filePath': filePath,
    'downloadUrl': downloadUrl,
    'quantization': quantization.name,
    'parameterCount': parameterCount,
    'contextLength': contextLength,
    'supportsVision': supportsVision,
    'supportsFunctionCalling': supportsFunctionCalling,
    'languages': languages,
    'credibility': credibility.name,
    'provider': provider.name,
    'description': description,
    'version': version,
    'author': author,
    'license': license,
    'huggingFaceId': huggingFaceId,
    'sha256': sha256,
    'tags': tags,
    'minMemoryBytes': minMemoryBytes,
    'recommendedMemoryBytes': recommendedMemoryBytes,
  };

  /// Creates from JSON map.
  factory OfflineModelInfo.fromJson(Map<String, dynamic> json) {
    return OfflineModelInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      family: ModelFamily.values.firstWhere(
        (f) => f.name == json['family'],
        orElse: () => ModelFamily.other,
      ),
      fileSizeBytes: json['fileSizeBytes'] as int,
      filePath: json['filePath'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      quantization: ModelQuantization.values.firstWhere(
        (q) => q.name == json['quantization'],
        orElse: () => ModelQuantization.unknown,
      ),
      parameterCount: json['parameterCount'] as int?,
      contextLength: json['contextLength'] as int? ?? 2048,
      supportsVision: json['supportsVision'] as bool? ?? false,
      supportsFunctionCalling:
          json['supportsFunctionCalling'] as bool? ?? false,
      languages: List<String>.from(json['languages'] ?? ['en']),
      credibility: ModelCredibility.values.firstWhere(
        (c) => c.name == json['credibility'],
        orElse: () => ModelCredibility.community,
      ),
      provider: AIProvider.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => AIProvider.gguf,
      ),
      description: json['description'] as String?,
      version: json['version'] as String?,
      author: json['author'] as String?,
      license: json['license'] as String?,
      huggingFaceId: json['huggingFaceId'] as String?,
      sha256: json['sha256'] as String?,
      tags: List<String>.from(json['tags'] ?? []),
      minMemoryBytes: json['minMemoryBytes'] as int?,
      recommendedMemoryBytes: json['recommendedMemoryBytes'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineModelInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'OfflineModelInfo($name, ${quantization.displayName}, '
      '$fileSizeDisplay)';
}
