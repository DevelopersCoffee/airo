import 'package:dio/dio.dart';

import '../models/model_credibility.dart';
import '../models/offline_model_info.dart';
import '../provider/ai_provider.dart';
import '../registry/model_catalog.dart';
import '../registry/model_registry.dart';

/// Fetches public Hugging Face model repos so users can try new releases
/// without waiting for a static catalog update.
class HuggingFaceCatalogService {
  HuggingFaceCatalogService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;

  static const _supportedArtifactSuffixes = [
    '.litertlm',
    '.task',
    '.tflite',
    '.gguf',
  ];

  /// Loads runnable artifacts from a public Hugging Face organization feed.
  ///
  /// [knownHuggingFaceIds] skips repos already present in [ModelCatalog.bundledModels]
  /// so the registry does not show duplicate rows.
  Future<List<OfflineModelInfo>> fetchOrganizationModels({
    String author = 'litert-community',
    int limit = 50,
    Set<String> knownHuggingFaceIds = const {},
  }) async {
    final response = await _dio.get<List<dynamic>>(
      'https://huggingface.co/api/models',
      queryParameters: {
        'author': author,
        'sort': 'lastModified',
        'direction': '-1',
        'limit': limit,
      },
    );
    final entries = response.data ?? const [];
    final models = <OfflineModelInfo>[];
    for (final raw in entries) {
      if (raw is! Map<String, dynamic>) continue;
      final modelId = raw['id'] as String?;
      if (modelId == null || modelId.isEmpty) continue;
      if (knownHuggingFaceIds.contains(modelId)) continue;
      final parsed = await _modelFromRepo(raw);
      if (parsed != null) {
        models.add(parsed);
      }
    }
    return models;
  }

  Future<OfflineModelInfo?> _modelFromRepo(Map<String, dynamic> raw) async {
    final huggingFaceId = raw['id'] as String?;
    if (huggingFaceId == null || huggingFaceId.isEmpty) return null;

    final tree = await _fetchMainTree(huggingFaceId);
    if (tree.isEmpty) return null;

    final artifact = _selectArtifact(tree);
    if (artifact == null) return null;

    final fileName = artifact['path'] as String;
    final size = (artifact['size'] as num?)?.toInt() ?? 0;
    if (size <= 0) return null;

    final slug = huggingFaceId.split('/').last;
    final tags = (raw['tags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final pipelineTag = raw['pipeline_tag'] as String? ?? '';
    final libraryName = raw['library_name'] as String? ?? '';

    return OfflineModelInfo(
      id: 'hf-$slug',
      name: _displayName(slug),
      family: _familyFromTags(tags),
      fileSizeBytes: size,
      downloadUrl:
          'https://huggingface.co/$huggingFaceId/resolve/main/$fileName',
      credibility: authorCredibility(huggingFaceId),
      provider: AIProvider.custom,
      description:
          'Public Hugging Face release from $huggingFaceId. '
          'Fetched live so new LiteRT/GGUF packages appear without an app update.',
      author: huggingFaceId.split('/').first,
      license: _licenseFromTags(tags),
      huggingFaceId: huggingFaceId,
      modalities: _modalitiesFromTags(tags, pipelineTag),
      capabilities: _capabilitiesFromTags(tags, pipelineTag, libraryName),
      tags: ['huggingface', 'community-feed', ...tags.take(6)],
      backendPreference: fileName.endsWith('.gguf')
          ? ModelBackendPreference.cpu
          : ModelBackendPreference.gpu,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMainTree(String huggingFaceId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        'https://huggingface.co/api/models/$huggingFaceId/tree/main',
      );
      return response.data
              ?.whereType<Map<String, dynamic>>()
              .where((entry) => entry['type'] == 'file')
              .toList(growable: false) ??
          const [];
    } on DioException {
      return const [];
    }
  }

  Map<String, dynamic>? _selectArtifact(List<Map<String, dynamic>> tree) {
    for (final suffix in _supportedArtifactSuffixes) {
      for (final entry in tree) {
        final path = entry['path'] as String?;
        if (path != null && path.endsWith(suffix)) {
          return entry;
        }
      }
    }
    return null;
  }

  static ModelCredibility authorCredibility(String huggingFaceId) {
    final author = huggingFaceId.split('/').first;
    if (author == 'litert-community' || author == 'google') {
      return ModelCredibility.official;
    }
    return ModelCredibility.community;
  }

  static String _displayName(String slug) =>
      slug.replaceAll('-', ' ').replaceAll('_', ' ');

  static String? _licenseFromTags(List<String> tags) {
    for (final tag in tags) {
      if (tag.startsWith('license:')) {
        return tag.substring('license:'.length);
      }
    }
    return null;
  }

  static ModelFamily _familyFromTags(List<String> tags) {
    for (final tag in tags) {
      final lower = tag.toLowerCase();
      if (lower.contains('gemma')) return ModelFamily.gemma;
      if (lower.contains('qwen')) return ModelFamily.qwen;
      if (lower.contains('phi')) return ModelFamily.phi;
      if (lower.contains('llama')) return ModelFamily.llama;
      if (lower.contains('mistral')) return ModelFamily.mistral;
    }
    return ModelFamily.other;
  }

  static List<ModelModality> _modalitiesFromTags(
    List<String> tags,
    String pipelineTag,
  ) {
    final joined = '${tags.join(' ')} $pipelineTag'.toLowerCase();
    final modalities = <ModelModality>[ModelModality.text];
    if (joined.contains('vision') ||
        joined.contains('image') ||
        joined.contains('vlm') ||
        pipelineTag.contains('image')) {
      modalities.add(ModelModality.image);
    }
    if (joined.contains('audio')) {
      modalities.add(ModelModality.audio);
    }
    return modalities;
  }

  static List<ModelCapability> _capabilitiesFromTags(
    List<String> tags,
    String pipelineTag,
    String libraryName,
  ) {
    final joined =
        '${tags.join(' ')} $pipelineTag $libraryName'.toLowerCase();
    final capabilities = <ModelCapability>[ModelCapability.chat];
    if (joined.contains('embed')) {
      capabilities
        ..clear()
        ..add(ModelCapability.embeddings);
    }
    if (joined.contains('vision') || joined.contains('image')) {
      capabilities.add(ModelCapability.imageUnderstanding);
    }
    if (joined.contains('audio')) {
      capabilities.add(ModelCapability.audioUnderstanding);
    }
    if (joined.contains('agent') || joined.contains('function')) {
      capabilities.add(ModelCapability.agentSkills);
    }
    return capabilities;
  }
}

/// Registers freshly released public Hugging Face repos into [registry].
///
/// Failures are silent: the bundled catalog still works when offline.
Future<void> hydratePublicHuggingFaceModels(
  ModelRegistry registry, {
  HuggingFaceCatalogService? service,
  String author = 'litert-community',
  int limit = 50,
}) async {
  final knownIds = {
    for (final model in ModelCatalog.bundledModels)
      if (model.huggingFaceId != null) model.huggingFaceId!,
  };
  try {
    final fetched =
        await (service ?? HuggingFaceCatalogService()).fetchOrganizationModels(
          author: author,
          limit: limit,
          knownHuggingFaceIds: knownIds,
        );
    if (fetched.isNotEmpty) {
      registry.registerModels(fetched);
    }
  } on Object {
    // Offline or API errors must not block the model explorer.
  }
}
