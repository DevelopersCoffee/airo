import 'package:core_ai/core_ai.dart';

import '../../features/agent_chat/domain/models/assistant_runtime_ids.dart';
import '../../features/agent_chat/presentation/screens/model_library_screen.dart';
import 'gemini_nano_service.dart';
import 'litert_lm_service.dart';

class LocalRuntimePreloaderService {
  factory LocalRuntimePreloaderService({
    GeminiNanoService? geminiNano,
    LiteRtLmService? liteRtLm,
    ModelResidencyManager? residencyManager,
    ModelPreloader? preloader,
    Future<AssistantModelLibraryState> Function()? loadAssistantModelLibrary,
    String? Function()? selectedModelId,
    bool Function()? isGenerationActive,
  }) {
    final resolvedResidencyManager =
        residencyManager ??
        ModelResidencyManager(loadBudgetBytes: _loadDefaultBudgetBytes);
    return LocalRuntimePreloaderService._(
      geminiNano: geminiNano ?? GeminiNanoService(),
      liteRtLm: liteRtLm ?? LiteRtLmService(),
      residencyManager: resolvedResidencyManager,
      preloader:
          preloader ??
          ModelPreloader(
            residencyManager: resolvedResidencyManager,
            isGenerationActive: isGenerationActive,
          ),
      loadAssistantModelLibrary:
          loadAssistantModelLibrary ?? _defaultAssistantModelLibraryState,
      selectedModelId: selectedModelId ?? (() => null),
    );
  }

  LocalRuntimePreloaderService._({
    required GeminiNanoService geminiNano,
    required LiteRtLmService liteRtLm,
    required ModelResidencyManager residencyManager,
    required ModelPreloader preloader,
    required Future<AssistantModelLibraryState> Function()
    loadAssistantModelLibrary,
    required String? Function() selectedModelId,
  }) : _geminiNano = geminiNano,
       _liteRtLm = liteRtLm,
       _residencyManager = residencyManager,
       _preloader = preloader,
       _loadAssistantModelLibrary = loadAssistantModelLibrary,
       _selectedModelId = selectedModelId;

  final GeminiNanoService _geminiNano;
  final LiteRtLmService _liteRtLm;
  final ModelResidencyManager _residencyManager;
  final ModelPreloader _preloader;
  final Future<AssistantModelLibraryState> Function()
  _loadAssistantModelLibrary;
  final String? Function() _selectedModelId;

  void abortPreload() {
    _preloader.abortPreload();
  }

  Future<ModelPreloadReport> preloadSelectedModels() async {
    final library = await _loadAssistantModelLibrary();
    final adapters = await _buildAdapters(library);
    return _preloader.preloadSelectedModels(adapters: adapters);
  }

  Future<List<ModelWarmupAdapter>> _buildAdapters(
    AssistantModelLibraryState library,
  ) async {
    final selectedModelId = _selectedModelId();
    final selectedCandidate = selectedModelId == null
        ? null
        : library.candidateById(selectedModelId);
    final selectedPackage = selectedCandidate?.package;

    return [
      _GeminiNanoWarmupAdapter(_geminiNano),
      if (selectedPackage != null &&
          selectedCandidate?.id != geminiNanoAssistantModelId)
        _LiteRtPackageWarmupAdapter(_liteRtLm, selectedPackage)
      else
        _LiteRtInstalledWarmupAdapter(_liteRtLm),
      NoOpWarmupAdapter(
        const ModelResidentSpec(
          id: 'assistant-tts-hook',
          residentType: ResidentRuntimeType.tts,
          estimatedMemoryBytes: 192 * 1024 * 1024,
          sidecar: true,
        ),
      ),
      NoOpWarmupAdapter(
        const ModelResidentSpec(
          id: 'assistant-stt-hook',
          residentType: ResidentRuntimeType.stt,
          estimatedMemoryBytes: 384 * 1024 * 1024,
          sidecar: true,
        ),
      ),
    ];
  }

  List<ModelResidentSpec> get currentResidents => _residencyManager.residents;

  static Future<AssistantModelLibraryState>
  _defaultAssistantModelLibraryState() async {
    const recommended = AssistantModelCandidate(
      id: geminiCloudAssistantModelId,
      name: 'Gemini Cloud',
      runtime: 'Cloud',
      description: 'Fallback cloud runtime',
      bestFor: [AssistantTask.chat],
      tags: ['Cloud'],
      privacyLabel: 'Sends prompt to API',
      sizeLabel: 'No local download',
      available: true,
      actionLabel: 'Start',
      local: false,
    );
    return const AssistantModelLibraryState(
      task: AssistantTask.chat,
      deviceLabel: 'Unknown device',
      platformLabel: 'DEVICE',
      candidates: [recommended],
      recommended: recommended,
      defaultPackages: {},
    );
  }

  static Future<int> _loadDefaultBudgetBytes() async {
    const fallbackBudgetBytes = 4 * 1024 * 1024 * 1024;
    final memoryBudgetManager = MemoryBudgetManager();
    final memoryInfo = await memoryBudgetManager.getCurrentMemoryInfo(
      forceRefresh: true,
    );
    if (!memoryInfo.isAvailable) {
      return fallbackBudgetBytes;
    }
    final budgetBytes = memoryBudgetManager.calculateBudget(memoryInfo);
    return budgetBytes > 0 ? budgetBytes : fallbackBudgetBytes;
  }
}

class _GeminiNanoWarmupAdapter implements ModelWarmupAdapter {
  _GeminiNanoWarmupAdapter(this._service);

  final GeminiNanoService _service;

  @override
  ModelResidentSpec get residentSpec => const ModelResidentSpec(
    id: geminiNanoAssistantModelId,
    residentType: ResidentRuntimeType.text,
    estimatedMemoryBytes: 1024 * 1024 * 1024,
  );

  @override
  Future<bool> isAvailable() => _service.isSupported();

  @override
  Future<bool> warmup() => _service.warmup();
}

class _LiteRtInstalledWarmupAdapter implements ModelWarmupAdapter {
  _LiteRtInstalledWarmupAdapter(this._service);

  final LiteRtLmService _service;

  @override
  ModelResidentSpec get residentSpec => const ModelResidentSpec(
    id: litertGemmaAssistantModelId,
    residentType: ResidentRuntimeType.text,
    estimatedMemoryBytes: 1536 * 1024 * 1024,
  );

  @override
  Future<bool> isAvailable() => _service.isAvailable();

  @override
  Future<bool> warmup() => _service.warmupInstalledModel();
}

class _LiteRtPackageWarmupAdapter implements ModelWarmupAdapter {
  _LiteRtPackageWarmupAdapter(this._service, this._package);

  final LiteRtLmService _service;
  final OfflineModelInfo _package;

  @override
  ModelResidentSpec get residentSpec => ModelResidentSpec(
    id: _package.id,
    residentType: _package.supportsVision
        ? ResidentRuntimeType.image
        : ResidentRuntimeType.text,
    estimatedMemoryBytes:
        _package.recommendedMemoryBytes ??
        _package.minMemoryBytes ??
        (_package.fileSizeBytes * 1.5).round(),
  );

  @override
  Future<bool> isAvailable() async {
    final hydrated = await _service.hydrateDownloadedModel(_package);
    return hydrated.filePath?.trim().isNotEmpty == true;
  }

  @override
  Future<bool> warmup() => _service.warmupModel(_package);
}
