import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/model_credibility.dart';
import '../models/model_runtime_profile.dart';
import '../models/offline_model_info.dart';
import '../provider/ai_provider.dart';
import '../registry/model_catalog.dart';
import '../registry/model_registry.dart';
import 'huggingface_catalog_cache.dart';

/// How Hugging Face catalog rows were resolved for the model explorer.
enum HuggingFaceCatalogAvailability {
  /// Live fetch succeeded and the disk cache was refreshed.
  online,

  /// Network failed; previously cached metadata is shown.
  offlineCached,

  /// Never successfully fetched — show a clear empty/error state.
  neverFetched,
}

/// Outcome of hydrating public Hugging Face rows into [ModelRegistry].
class HuggingFaceCatalogHydration {
  const HuggingFaceCatalogHydration({
    required this.availability,
    required this.models,
    this.errorMessage,
  });

  final HuggingFaceCatalogAvailability availability;
  final List<OfflineModelInfo> models;
  final String? errorMessage;

  bool get hasRemoteEntries => models.isNotEmpty;
}

/// Fetches public Hugging Face model repos so users can try new releases
/// without waiting for a static catalog update.
///
/// Extends the litert-community feed from #1769 with a GGUF discovery path and
/// an offline metadata cache for already-seen entries.
class HuggingFaceCatalogService {
  HuggingFaceCatalogService({Dio? dio, HuggingFaceCatalogCache? cache})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {'Accept': 'application/json'},
              responseType: ResponseType.bytes,
            ),
          ),
      _cache = cache ?? HuggingFaceCatalogCache();

  final Dio _dio;
  final HuggingFaceCatalogCache _cache;

  static const _supportedArtifactSuffixes = [
    '.litertlm',
    '.task',
    '.tflite',
    '.gguf',
  ];

  HuggingFaceCatalogCache get cache => _cache;

  /// Loads runnable artifacts from a public Hugging Face organization feed.
  ///
  /// [knownHuggingFaceIds] skips repos already present in [ModelCatalog.bundledModels]
  /// so the registry does not show duplicate rows.
  Future<List<OfflineModelInfo>> fetchOrganizationModels({
    String author = 'litert-community',
    int limit = 50,
    Set<String> knownHuggingFaceIds = const {},
  }) async {
    final entries = await _getJsonList(
      'https://huggingface.co/api/models',
      queryParameters: {
        'author': author,
        'sort': 'lastModified',
        'direction': '-1',
        'limit': limit,
      },
    );
    return _modelsFromEntries(
      entries,
      knownHuggingFaceIds: knownHuggingFaceIds,
    );
  }

  /// Hugging Face org that publishes public Gemma GGUF for llama.cpp.
  ///
  /// Google's own `google/gemma*` weight repos are gated (HTTP 401 without a
  /// token). Unsloth GGUF exports are the login-free download path for desktop
  /// and mobile llama.cpp — not the Python/CUDA `unsloth` training package.
  static const unslothAuthor = 'unsloth';

  /// Discovers public GGUF packages beyond the litert-community LiteRT feed.
  ///
  /// Uses the Hugging Face `gguf` filter and prefers mobile-friendly quants
  /// (Q4_K_M → Q4 → Q5 → smallest remaining GGUF). When [authors] is non-empty,
  /// queries each author separately (HF accepts one `author` per request).
  Future<List<OfflineModelInfo>> fetchGgufModels({
    int limit = 40,
    Set<String> knownHuggingFaceIds = const {},
    String sort = 'downloads',
    String? search,
    List<String> authors = const [],
  }) async {
    if (authors.isEmpty) {
      return _fetchGgufPage(
        limit: limit,
        knownHuggingFaceIds: knownHuggingFaceIds,
        sort: sort,
        search: search,
      );
    }

    final perAuthor = (limit / authors.length).ceil().clamp(1, limit);
    final merged = <OfflineModelInfo>[];
    final seen = <String>{...knownHuggingFaceIds};
    for (final author in authors) {
      final page = await _fetchGgufPage(
        limit: perAuthor,
        knownHuggingFaceIds: seen,
        sort: sort,
        search: search,
        author: author,
      );
      for (final model in page) {
        final hfId = model.huggingFaceId;
        if (hfId != null) seen.add(hfId);
        merged.add(model);
      }
      if (merged.length >= limit) break;
    }
    return merged.take(limit).toList(growable: false);
  }

  Future<List<OfflineModelInfo>> _fetchGgufPage({
    required int limit,
    required Set<String> knownHuggingFaceIds,
    required String sort,
    String? search,
    String? author,
  }) async {
    final query = <String, dynamic>{
      'filter': 'gguf',
      'sort': sort,
      'direction': '-1',
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }
    if (author != null && author.isNotEmpty) {
      query['author'] = author;
    }
    final entries = await _getJsonList(
      'https://huggingface.co/api/models',
      queryParameters: query,
    );
    return _modelsFromEntries(
      entries,
      knownHuggingFaceIds: knownHuggingFaceIds,
      ggufOnly: true,
    );
  }

  /// Resolves a pasted Hugging Face repo URL or bare `author/name` id.
  ///
  /// Does not download weights — only builds an [OfflineModelInfo] catalog row
  /// when a supported artifact exists in the repo tree.
  Future<OfflineModelInfo?> resolveFromRepoUrl(
    String urlOrId, {
    Set<String> knownHuggingFaceIds = const {},
  }) async {
    final huggingFaceId = parseHuggingFaceRepoId(urlOrId);
    if (huggingFaceId == null) return null;
    if (knownHuggingFaceIds.contains(huggingFaceId)) return null;

    Map<String, dynamic> raw = {'id': huggingFaceId};
    try {
      final card = await _getJsonMap(
        'https://huggingface.co/api/models/$huggingFaceId',
      );
      if (card != null) raw = card;
    } on DioException {
      // Tree fetch below still works when the card endpoint fails.
    }

    return _modelFromRepo(raw);
  }

  /// Parses `https://huggingface.co/org/repo` (and `/tree/...`) or bare
  /// `org/repo`. Returns null when the string is not a repo reference.
  static String? parseHuggingFaceRepoId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final asUri = Uri.tryParse(trimmed);
    if (asUri != null &&
        asUri.hasScheme &&
        (asUri.host == 'huggingface.co' ||
            asUri.host == 'www.huggingface.co' ||
            asUri.host == 'hf.co')) {
      final segments = asUri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
      if (segments.length >= 2) {
        return '${segments[0]}/${segments[1]}';
      }
      return null;
    }

    if (RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  Future<List<OfflineModelInfo>> _modelsFromEntries(
    List<dynamic> entries, {
    required Set<String> knownHuggingFaceIds,
    bool ggufOnly = false,
  }) async {
    final models = <OfflineModelInfo>[];
    for (final raw in entries) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final modelId = map['id'] as String?;
      if (modelId == null || modelId.isEmpty) continue;
      if (knownHuggingFaceIds.contains(modelId)) continue;
      if (isGatedHuggingFaceRepo(map)) continue;
      if (_isTrainingOnlyQuant(modelId)) continue;
      final parsed = await _modelFromRepo(map, ggufOnly: ggufOnly);
      if (parsed != null) {
        models.add(parsed);
      }
    }
    return models;
  }

  Future<OfflineModelInfo?> _modelFromRepo(
    Map<String, dynamic> raw, {
    bool ggufOnly = false,
  }) async {
    final huggingFaceId = raw['id'] as String?;
    if (huggingFaceId == null || huggingFaceId.isEmpty) return null;
    if (isGatedHuggingFaceRepo(raw)) return null;
    if (_isTrainingOnlyQuant(huggingFaceId)) return null;

    final tree = await _fetchMainTree(huggingFaceId);
    if (tree.isEmpty) return null;

    final artifact = ggufOnly
        ? _selectGgufArtifact(tree)
        : _selectArtifact(tree);
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
    final isGguf = fileName.toLowerCase().endsWith('.gguf');
    final license = _licenseFromTags(tags);
    final quantization = isGguf
        ? quantizationFromFileName(fileName)
        : ModelQuantization.unknown;

    return OfflineModelInfo(
      id: 'hf-$slug',
      name: _displayName(slug),
      family: _familyFromTags(tags, slug),
      fileSizeBytes: size,
      downloadUrl:
          'https://huggingface.co/$huggingFaceId/resolve/main/$fileName',
      quantization: quantization,
      parameterCount: parameterCountFromSlug(slug),
      credibility: authorCredibility(huggingFaceId),
      provider: isGguf ? AIProvider.gguf : AIProvider.custom,
      description: isGguf
          ? 'Public GGUF package from $huggingFaceId '
                '(${quantization.displayName}, ${license ?? 'license unknown'}). '
                'Fetched live so new GGUF releases appear without an app update.'
          : 'Public Hugging Face release from $huggingFaceId. '
                'Fetched live so new LiteRT/GGUF packages appear without an app update.',
      author: huggingFaceId.split('/').first,
      license: license,
      licenseState: _licenseStateFromTags(tags),
      huggingFaceId: huggingFaceId,
      modalities: _modalitiesFromTags(tags, pipelineTag),
      capabilities: _capabilitiesFromTags(tags, pipelineTag, libraryName),
      tags: [
        'huggingface',
        if (isGguf) 'gguf' else 'community-feed',
        ...tags.take(6),
      ],
      backendPreference: isGguf
          ? ModelBackendPreference.cpu
          : ModelBackendPreference.gpu,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMainTree(
    String huggingFaceId,
  ) async {
    try {
      final entries = await _getJsonList(
        'https://huggingface.co/api/models/$huggingFaceId/tree/main',
      );
      return entries
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where((entry) => entry['type'] == 'file')
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<List<dynamic>> _getJsonList(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? const <int>[]);
    return decodeCatalogJson(bytes);
  }

  Future<Map<String, dynamic>?> _getJsonMap(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(response.data ?? const <int>[]);
    if (bytes.isEmpty) return null;
    final decoded = await decodeCatalogJsonObject(bytes);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Map<String, dynamic>? _selectArtifact(List<Map<String, dynamic>> tree) {
    for (final suffix in _supportedArtifactSuffixes) {
      for (final entry in tree) {
        final path = entry['path'] as String?;
        if (path != null && path.toLowerCase().endsWith(suffix)) {
          return entry;
        }
      }
    }
    return null;
  }

  /// Prefers mobile-friendly GGUF quants over the first file in the tree.
  Map<String, dynamic>? _selectGgufArtifact(List<Map<String, dynamic>> tree) {
    final ggufs = tree
        .where((entry) {
          final path = entry['path'] as String?;
          return path != null && _isPrimaryGguf(path);
        })
        .toList(growable: false);
    if (ggufs.isEmpty) return null;

    int score(Map<String, dynamic> entry) {
      final path = (entry['path'] as String).toLowerCase();
      if (path.contains('q4_k_m')) return 0;
      if (path.contains('q4_k_s')) return 1;
      if (path.contains('q4_0') || path.contains('q4_1')) return 2;
      if (RegExp(r'q4[^0-9]').hasMatch(path) || path.contains('-q4')) {
        return 3;
      }
      if (path.contains('q5_k_m')) return 4;
      if (path.contains('q5')) return 5;
      if (path.contains('q3')) return 6;
      if (path.contains('q6') || path.contains('q8')) return 7;
      return 8;
    }

    ggufs.sort((a, b) {
      final byScore = score(a).compareTo(score(b));
      if (byScore != 0) return byScore;
      final sizeA = (a['size'] as num?)?.toInt() ?? 1 << 62;
      final sizeB = (b['size'] as num?)?.toInt() ?? 1 << 62;
      return sizeA.compareTo(sizeB);
    });
    return ggufs.first;
  }

  static bool _isPrimaryGguf(String path) {
    final lower = path.toLowerCase();
    if (!lower.endsWith('.gguf')) return false;
    if (lower.contains('mmproj')) return false;
    if (lower.contains('imatrix')) return false;
    if (lower.contains('ggml-vocab')) return false;
    return true;
  }

  /// True when Hub metadata says the repo needs a token / license click.
  ///
  /// Google Gemma GGUF is always gated even when the list payload omits the
  /// `gated` field. Unsloth Gemma GGUF is public (`gated: false`).
  static bool isGatedHuggingFaceRepo(Map<String, dynamic> raw) {
    final gated = raw['gated'];
    if (gated == true) return true;
    if (gated is String) {
      final normalized = gated.trim().toLowerCase();
      if (normalized.isNotEmpty &&
          normalized != 'false' &&
          normalized != 'null') {
        return true;
      }
    }
    final id = (raw['id'] as String? ?? '').toLowerCase();
    if (id.startsWith('google/gemma')) return true;
    final tags = (raw['tags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((tag) => tag.toLowerCase());
    return tags.contains('gated');
  }

  static bool _isTrainingOnlyQuant(String huggingFaceId) {
    final lower = huggingFaceId.toLowerCase();
    return lower.contains('bnb-4bit') || lower.contains('bnb_4bit');
  }

  static bool _isInstructVariant(OfflineModelInfo model) {
    final haystack = '${model.huggingFaceId ?? ''} ${model.id} ${model.name}'
        .toLowerCase();
    return haystack.contains('-it') ||
        haystack.contains('_it') ||
        haystack.contains(' instruct');
  }

  /// Authors treated as official vendors / first-party orgs.
  static const officialAuthors = {
    'litert-community',
    'google',
    'google-bert',
    'meta-llama',
    'microsoft',
    'qwen',
    'mistralai',
  };

  /// Authors with a strong track record for GGUF packaging / conversion.
  static const verifiedAuthors = {
    'bartowski',
    'thebloke',
    'lmstudio-community',
    'unsloth',
    'ggerganov',
    'mlx-community',
  };

  /// Widely used community orgs (not formally verified packaging).
  static const popularAuthors = {
    'nousresearch',
    'huggingfaceh4',
    'tiiuae',
    'openchat',
  };

  static ModelCredibility authorCredibility(String huggingFaceId) {
    final author = huggingFaceId.split('/').first.toLowerCase();
    if (officialAuthors.contains(author)) {
      return ModelCredibility.official;
    }
    if (verifiedAuthors.contains(author)) {
      return ModelCredibility.verified;
    }
    if (popularAuthors.contains(author)) {
      return ModelCredibility.popular;
    }
    return ModelCredibility.community;
  }

  /// Maps a GGUF file name to [ModelQuantization] for model-manager display.
  static ModelQuantization quantizationFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('q2')) return ModelQuantization.q2;
    if (lower.contains('q3')) return ModelQuantization.q3;
    if (lower.contains('q4')) return ModelQuantization.q4;
    if (lower.contains('q5')) return ModelQuantization.q5;
    if (lower.contains('q6')) return ModelQuantization.q6;
    if (lower.contains('q8')) return ModelQuantization.q8;
    if (lower.contains('f16') || lower.contains('fp16')) {
      return ModelQuantization.fp16;
    }
    return ModelQuantization.unknown;
  }

  /// Best-effort parameter count from repo slugs like `Qwen2.5-0.5B-Instruct`.
  static int? parameterCountFromSlug(String slug) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*[bB](?:-|_|\.|$)',
    ).firstMatch(slug.replaceAll('_', '-'));
    if (match == null) return null;
    final billions = double.tryParse(match.group(1)!);
    if (billions == null) return null;
    return (billions * 1000000000).round();
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

  static ModelLicenseState _licenseStateFromTags(List<String> tags) {
    final joined = tags.join(' ').toLowerCase();
    if (joined.contains('gated') ||
        joined.contains('license:other') ||
        joined.contains('llama2') ||
        joined.contains('llama-2') ||
        joined.contains('llama3') ||
        joined.contains('llama-3')) {
      return ModelLicenseState.gated;
    }
    if (tags.any((tag) => tag.startsWith('license:'))) {
      return ModelLicenseState.open;
    }
    return ModelLicenseState.unknown;
  }

  static ModelFamily _familyFromTags(List<String> tags, String slug) {
    final haystack = '${tags.join(' ')} $slug'.toLowerCase();
    if (haystack.contains('gemma')) return ModelFamily.gemma;
    if (haystack.contains('qwen')) return ModelFamily.qwen;
    if (haystack.contains('phi')) return ModelFamily.phi;
    if (haystack.contains('llama')) return ModelFamily.llama;
    if (haystack.contains('mistral')) return ModelFamily.mistral;
    if (haystack.contains('stablelm') || haystack.contains('stable-lm')) {
      return ModelFamily.stableLM;
    }
    if (haystack.contains('falcon')) return ModelFamily.falcon;
    if (haystack.contains('mpt')) return ModelFamily.mpt;
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
    final joined = '${tags.join(' ')} $pipelineTag $libraryName'.toLowerCase();
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

/// Registers public Hugging Face repos into [registry], extending the #1769 hub.
///
/// Flow:
/// 1. Register cached metadata immediately when present (offline browse).
/// 2. Fetch litert-community + GGUF discovery in parallel.
/// 3. On success, merge into the registry and refresh the disk cache.
/// 4. On failure with no cache, leave availability as [neverFetched].
Future<HuggingFaceCatalogHydration> hydratePublicHuggingFaceModels(
  ModelRegistry registry, {
  HuggingFaceCatalogService? service,
  HuggingFaceCatalogCache? cache,
  String author = 'litert-community',
  int organizationLimit = 50,
  int ggufLimit = 40,
  ModelRuntimeProfile profile = ModelRuntimeProfile.androidOnDevice,
}) async {
  final catalogService = service ?? HuggingFaceCatalogService(cache: cache);
  final catalogCache = cache ?? catalogService.cache;

  List<OfflineModelInfo> accept(Iterable<OfflineModelInfo> models) {
    final public = models.where(_isPublicGgufOrLiteRtRow);
    if (profile == ModelRuntimeProfile.androidOnDevice) {
      return public.toList(growable: false);
    }
    return public.where(profile.offersPackage).toList(growable: false);
  }

  final bundledIds = {
    for (final model in ModelCatalog.forProfile(profile))
      if (model.huggingFaceId != null) model.huggingFaceId!,
  };

  final cached = await catalogCache.load();
  final cachedWithoutBundled = accept(
    cached.where(
      (model) =>
          model.huggingFaceId == null ||
          !bundledIds.contains(model.huggingFaceId),
    ),
  );
  if (cachedWithoutBundled.isNotEmpty) {
    registry.registerModels(cachedWithoutBundled);
  }

  final knownIds = {
    ...bundledIds,
    for (final model in cachedWithoutBundled)
      if (model.huggingFaceId != null) model.huggingFaceId!,
  };

  try {
    // LiteRT org feed, live Unsloth Gemma GGUF, and general public GGUF.
    // Google's own Gemma GGUF repos are gated (HTTP 401) and skipped.
    final results = await Future.wait([
      if (profile.offersLiteRt)
        catalogService.fetchOrganizationModels(
          author: author,
          limit: organizationLimit,
          knownHuggingFaceIds: knownIds,
        )
      else
        Future.value(const <OfflineModelInfo>[]),
      catalogService
          .fetchGgufModels(
            limit: ggufLimit,
            knownHuggingFaceIds: knownIds,
            authors: const [HuggingFaceCatalogService.unslothAuthor],
            search: 'gemma',
            sort: 'lastModified',
          )
          .then(
            (models) => models
                .where(HuggingFaceCatalogService._isInstructVariant)
                .toList(growable: false),
          ),
      catalogService.fetchGgufModels(
        limit: ggufLimit,
        knownHuggingFaceIds: knownIds,
      ),
    ]);
    final fetched = accept(
      _dedupeById([...results[0], ...results[1], ...results[2]]),
    );
    if (fetched.isNotEmpty) {
      registry.registerModels(fetched);
      final merged = _dedupeById([...cachedWithoutBundled, ...fetched]);
      await catalogCache.save(merged);
      return HuggingFaceCatalogHydration(
        availability: HuggingFaceCatalogAvailability.online,
        models: merged,
      );
    }

    // Network reached HF but returned nothing new — still "online".
    if (cachedWithoutBundled.isNotEmpty) {
      return HuggingFaceCatalogHydration(
        availability: HuggingFaceCatalogAvailability.online,
        models: cachedWithoutBundled,
      );
    }
    return const HuggingFaceCatalogHydration(
      availability: HuggingFaceCatalogAvailability.neverFetched,
      models: [],
    );
  } on Object catch (error) {
    if (cachedWithoutBundled.isNotEmpty) {
      return HuggingFaceCatalogHydration(
        availability: HuggingFaceCatalogAvailability.offlineCached,
        models: cachedWithoutBundled,
        errorMessage: error.toString(),
      );
    }
    return HuggingFaceCatalogHydration(
      availability: HuggingFaceCatalogAvailability.neverFetched,
      models: const [],
      errorMessage: error.toString(),
    );
  }
}

bool _isPublicGgufOrLiteRtRow(OfflineModelInfo model) {
  final hf = (model.huggingFaceId ?? '').toLowerCase();
  if (hf.startsWith('google/gemma')) return false;
  final url = (model.downloadUrl ?? '').toLowerCase();
  if (url.contains('huggingface.co/google/gemma') && url.contains('.gguf')) {
    return false;
  }
  return true;
}

List<OfflineModelInfo> _dedupeById(List<OfflineModelInfo> models) {
  final seen = <String>{};
  final out = <OfflineModelInfo>[];
  for (final model in models) {
    if (seen.add(model.id)) {
      out.add(model);
    }
  }
  return out;
}

// Keep Isolate-safe JSON helpers reachable for tests that import this library.
Future<List<dynamic>> decodeHuggingFaceApiJson(Uint8List bytes) =>
    decodeCatalogJson(bytes);

Future<Uint8List> encodeHuggingFaceCatalogJson(
  List<Map<String, dynamic>> models,
) => encodeCatalogJson(models);
