import '../../../../core/services/gemini_api_service.dart';
import '../../../../core/services/gemini_nano_service.dart';
import '../../../../core/services/litert_lm_service.dart';
import '../../presentation/screens/model_library_screen.dart';
import '../../domain/models/assistant_runtime_ids.dart';
import 'package:core_ai/core_ai.dart';

typedef GeminiNanoSupportCheck = Future<bool> Function();
typedef GeminiNanoInitializer = Future<bool> Function();
typedef GeminiNanoTextGenerator = Future<String> Function(String prompt);
typedef GeminiNanoStreamGenerator = Stream<String> Function(String prompt);
typedef LiteRtTextGenerator =
    Future<String?> Function(String prompt, {String? systemPrompt});
typedef LiteRtModelTextGenerator =
    Future<String?> Function(
      OfflineModelInfo model,
      String prompt, {
      String? systemPrompt,
    });
typedef CloudInitializer = Future<void> Function();
typedef CloudAvailabilityCheck = bool Function();
typedef CloudTextGenerator = Future<String?> Function(String prompt);
typedef GeminiNanoWarmup = Future<bool> Function();
typedef LiteRtAvailabilityCheck = Future<bool> Function();
typedef LiteRtWarmup = Future<bool> Function();
typedef LiteRtModelWarmup = Future<bool> Function(OfflineModelInfo model);
typedef DeviceInfoLoader = Future<Map<String, dynamic>> Function();
typedef ModelCompatibilityCheck =
    Future<ModelCompatibilityResult> Function(OfflineModelInfo model);

enum AssistantRuntimePreparationPhase {
  validate,
  allocate,
  load,
  warmup,
  ready,
}

enum AssistantRuntimePreparationStatus { ready, cancelled, blocked }

class AssistantRuntimePreparationProgress {
  const AssistantRuntimePreparationProgress({
    required this.phase,
    required this.progress,
    required this.label,
    required this.detail,
  });

  final AssistantRuntimePreparationPhase phase;
  final double progress;
  final String label;
  final String detail;
}

class AssistantRuntimeDiagnosticEnvelope {
  const AssistantRuntimeDiagnosticEnvelope({
    required this.runtimeId,
    required this.runtimeName,
    required this.summary,
    required this.detail,
    required this.deviceLabel,
    required this.platformLabel,
    required this.repairActions,
    this.reasonCode,
    this.availableMemoryMB,
    this.requiredMemoryMB,
  });

  final String runtimeId;
  final String runtimeName;
  final String summary;
  final String detail;
  final String deviceLabel;
  final String platformLabel;
  final List<String> repairActions;
  final String? reasonCode;
  final double? availableMemoryMB;
  final double? requiredMemoryMB;

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('Runtime: $runtimeName ($runtimeId)')
      ..writeln('Summary: $summary')
      ..writeln('Detail: $detail')
      ..writeln('Device: $deviceLabel')
      ..writeln('Platform: $platformLabel');
    if (reasonCode != null) {
      buffer.writeln('Reason code: $reasonCode');
    }
    if (availableMemoryMB != null || requiredMemoryMB != null) {
      buffer.writeln(
        'Memory MB: available=${availableMemoryMB?.toStringAsFixed(0) ?? 'n/a'}, '
        'required=${requiredMemoryMB?.toStringAsFixed(0) ?? 'n/a'}',
      );
    }
    if (repairActions.isNotEmpty) {
      buffer.writeln('Repair actions:');
      for (final action in repairActions) {
        buffer.writeln('- $action');
      }
    }
    return buffer.toString().trimRight();
  }
}

class AssistantRuntimePreparationResult {
  const AssistantRuntimePreparationResult._({
    required this.status,
    this.diagnostic,
  });

  final AssistantRuntimePreparationStatus status;
  final AssistantRuntimeDiagnosticEnvelope? diagnostic;

  bool get isReady => status == AssistantRuntimePreparationStatus.ready;

  factory AssistantRuntimePreparationResult.ready() =>
      const AssistantRuntimePreparationResult._(
        status: AssistantRuntimePreparationStatus.ready,
      );

  factory AssistantRuntimePreparationResult.cancelled() =>
      const AssistantRuntimePreparationResult._(
        status: AssistantRuntimePreparationStatus.cancelled,
      );

  factory AssistantRuntimePreparationResult.blocked(
    AssistantRuntimeDiagnosticEnvelope diagnostic,
  ) => AssistantRuntimePreparationResult._(
    status: AssistantRuntimePreparationStatus.blocked,
    diagnostic: diagnostic,
  );
}

class AssistantRuntimeUnavailableException implements Exception {
  AssistantRuntimeUnavailableException(this.runtimeId, this.message);

  final String? runtimeId;
  final String message;

  @override
  String toString() => message;
}

class AssistantRuntimeService {
  AssistantRuntimeService({
    GeminiNanoService? geminiNano,
    LiteRtLmService? liteRtLm,
    GeminiApiService? geminiCloud,
    GeminiNanoSupportCheck? isGeminiNanoSupported,
    GeminiNanoInitializer? initializeGeminiNano,
    GeminiNanoTextGenerator? generateGeminiNanoText,
    GeminiNanoStreamGenerator? generateGeminiNanoStream,
    LiteRtTextGenerator? generateLiteRtText,
    LiteRtModelTextGenerator? generateLiteRtModelText,
    CloudInitializer? initializeCloud,
    CloudAvailabilityCheck? isCloudAvailable,
    CloudTextGenerator? generateCloudText,
    GeminiNanoWarmup? warmupGeminiNano,
    LiteRtAvailabilityCheck? isLiteRtAvailable,
    LiteRtWarmup? warmupLiteRtInstalledModel,
    LiteRtModelWarmup? warmupLiteRtModel,
    DeviceInfoLoader? loadDeviceInfo,
    ModelCompatibilityCheck? checkModelCompatibility,
    Future<AssistantModelLibraryState> Function()? loadAssistantModelLibrary,
  }) : _geminiNano = geminiNano ?? GeminiNanoService(),
       _liteRtLm = liteRtLm ?? LiteRtLmService(),
       _geminiCloud = geminiCloud ?? geminiApiService,
       _isGeminiNanoSupportedOverride = isGeminiNanoSupported,
       _initializeGeminiNanoOverride = initializeGeminiNano,
       _generateGeminiNanoTextOverride = generateGeminiNanoText,
       _generateGeminiNanoStreamOverride = generateGeminiNanoStream,
       _generateLiteRtTextOverride = generateLiteRtText,
       _generateLiteRtModelTextOverride = generateLiteRtModelText,
       _initializeCloudOverride = initializeCloud,
       _isCloudAvailableOverride = isCloudAvailable,
       _generateCloudTextOverride = generateCloudText,
       _warmupGeminiNanoOverride = warmupGeminiNano,
       _isLiteRtAvailableOverride = isLiteRtAvailable,
       _warmupLiteRtInstalledModelOverride = warmupLiteRtInstalledModel,
       _warmupLiteRtModelOverride = warmupLiteRtModel,
       _loadDeviceInfoOverride = loadDeviceInfo,
       _checkModelCompatibilityOverride = checkModelCompatibility,
       _loadAssistantModelLibraryOverride = loadAssistantModelLibrary;

  final GeminiNanoService _geminiNano;
  final LiteRtLmService _liteRtLm;
  final GeminiApiService _geminiCloud;
  final GeminiNanoSupportCheck? _isGeminiNanoSupportedOverride;
  final GeminiNanoInitializer? _initializeGeminiNanoOverride;
  final GeminiNanoTextGenerator? _generateGeminiNanoTextOverride;
  final GeminiNanoStreamGenerator? _generateGeminiNanoStreamOverride;
  final LiteRtTextGenerator? _generateLiteRtTextOverride;
  final LiteRtModelTextGenerator? _generateLiteRtModelTextOverride;
  final CloudInitializer? _initializeCloudOverride;
  final CloudAvailabilityCheck? _isCloudAvailableOverride;
  final CloudTextGenerator? _generateCloudTextOverride;
  final GeminiNanoWarmup? _warmupGeminiNanoOverride;
  final LiteRtAvailabilityCheck? _isLiteRtAvailableOverride;
  final LiteRtWarmup? _warmupLiteRtInstalledModelOverride;
  final LiteRtModelWarmup? _warmupLiteRtModelOverride;
  final DeviceInfoLoader? _loadDeviceInfoOverride;
  final ModelCompatibilityCheck? _checkModelCompatibilityOverride;
  final Future<AssistantModelLibraryState> Function()?
  _loadAssistantModelLibraryOverride;

  Future<AssistantRuntimePreparationResult> prepareRuntime({
    required AssistantModelCandidate candidate,
    void Function(AssistantRuntimePreparationProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    AssistantRuntimePreparationResult? cancelled() {
      if (isCancelled?.call() ?? false) {
        return AssistantRuntimePreparationResult.cancelled();
      }
      return null;
    }

    void emit(
      AssistantRuntimePreparationPhase phase,
      double progress,
      String label,
      String detail,
    ) {
      onProgress?.call(
        AssistantRuntimePreparationProgress(
          phase: phase,
          progress: progress,
          label: label,
          detail: detail,
        ),
      );
    }

    final deviceInfo =
        await (_loadDeviceInfoOverride?.call() ?? _geminiNano.getDeviceInfo());
    final platformLabel =
        (deviceInfo['platform'] as String?)?.toUpperCase() ?? 'DEVICE';
    final deviceLabel = [
      deviceInfo['manufacturer'],
      deviceInfo['model'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    final resolvedDeviceLabel = deviceLabel.isEmpty
        ? 'Unknown device'
        : deviceLabel;

    emit(
      AssistantRuntimePreparationPhase.validate,
      0.15,
      'Validate runtime',
      'Checking whether ${candidate.name} can launch on this device.',
    );
    final earlyCancel = cancelled();
    if (earlyCancel != null) return earlyCancel;

    if (!candidate.local) {
      emit(
        AssistantRuntimePreparationPhase.ready,
        1,
        'Runtime ready',
        '${candidate.name} does not require local initialization.',
      );
      return AssistantRuntimePreparationResult.ready();
    }

    switch (candidate.id) {
      case geminiNanoAssistantModelId:
        final supported =
            await (_isGeminiNanoSupportedOverride?.call() ??
                _geminiNano.isSupported());
        if (!supported) {
          return AssistantRuntimePreparationResult.blocked(
            AssistantRuntimeDiagnosticEnvelope(
              runtimeId: candidate.id,
              runtimeName: candidate.name,
              summary: 'Gemini Nano is not supported on this device.',
              detail:
                  'The native AICore integration reported that this runtime cannot launch safely here.',
              deviceLabel: resolvedDeviceLabel,
              platformLabel: platformLabel,
              reasonCode: 'unsupported_runtime',
              repairActions: const [
                'Switch to a LiteRT-LM local package.',
                'Open Profile > AI Models and download a compatible package.',
                'Use Gemini Cloud if local runtime setup is unavailable.',
              ],
            ),
          );
        }

        emit(
          AssistantRuntimePreparationPhase.allocate,
          0.4,
          'Allocate runtime',
          'Initializing Gemini Nano and validating the local runtime path.',
        );
        final initCancel = cancelled();
        if (initCancel != null) return initCancel;

        final initialized =
            await (_initializeGeminiNanoOverride?.call() ??
                _geminiNano.initialize());
        if (!initialized) {
          return AssistantRuntimePreparationResult.blocked(
            AssistantRuntimeDiagnosticEnvelope(
              runtimeId: candidate.id,
              runtimeName: candidate.name,
              summary: 'Gemini Nano initialization failed.',
              detail:
                  'AICore was detected, but initialization did not complete successfully.',
              deviceLabel: resolvedDeviceLabel,
              platformLabel: platformLabel,
              reasonCode: 'init_failed',
              repairActions: const [
                'Retry the local runtime initialization.',
                'Switch to a smaller local package or Gemini Cloud.',
                'Report the diagnostics if the failure repeats.',
              ],
            ),
          );
        }

        emit(
          AssistantRuntimePreparationPhase.warmup,
          0.82,
          'Warm up runtime',
          'Running a lightweight local warmup so the first response is safer.',
        );
        final warmCancel = cancelled();
        if (warmCancel != null) return warmCancel;
        await (_warmupGeminiNanoOverride?.call() ?? _geminiNano.warmup());

      case litertGemmaAssistantModelId:
      default:
        final available =
            await (_isLiteRtAvailableOverride?.call() ??
                _liteRtLm.isAvailable());
        if (!available) {
          return AssistantRuntimePreparationResult.blocked(
            AssistantRuntimeDiagnosticEnvelope(
              runtimeId: candidate.id,
              runtimeName: candidate.name,
              summary: 'The LiteRT-LM runtime is not ready.',
              detail:
                  'No compatible local model path or downloadable package is available for this runtime.',
              deviceLabel: resolvedDeviceLabel,
              platformLabel: platformLabel,
              reasonCode: 'runtime_unavailable',
              repairActions: const [
                'Open Profile > AI Models and install a compatible package.',
                'Set LITERT_LM_MODEL_PATH or LITERT_LM_MODEL_URL when launching locally.',
              ],
            ),
          );
        }

        final package = candidate.package;
        if (package != null) {
          final compatibility =
              await (_checkModelCompatibilityOverride?.call(package) ??
                  _checkCompatibility(package));
          if (!compatibility.isCompatible) {
            return AssistantRuntimePreparationResult.blocked(
              AssistantRuntimeDiagnosticEnvelope(
                runtimeId: candidate.id,
                runtimeName: candidate.name,
                summary:
                    'This local package exceeds the current device budget.',
                detail:
                    compatibility.reason ??
                    'The device compatibility check refused this package.',
                deviceLabel: resolvedDeviceLabel,
                platformLabel: platformLabel,
                reasonCode: 'compatibility_blocked',
                availableMemoryMB: compatibility.availableMemoryMB,
                requiredMemoryMB: compatibility.requiredMemoryMB,
                repairActions: const [
                  'Choose a smaller local package.',
                  'Switch to a cloud runtime for this task.',
                  'Free memory and retry initialization.',
                ],
              ),
            );
          }
        }

        emit(
          AssistantRuntimePreparationPhase.load,
          0.55,
          'Load runtime',
          'Preparing the local LiteRT-LM package for first use.',
        );
        final loadCancel = cancelled();
        if (loadCancel != null) return loadCancel;
        final warmed = package != null
            ? await (_warmupLiteRtModelOverride?.call(package) ??
                  _liteRtLm.warmupModel(package))
            : await (_warmupLiteRtInstalledModelOverride?.call() ??
                  _liteRtLm.warmupInstalledModel());
        if (!warmed) {
          return AssistantRuntimePreparationResult.blocked(
            AssistantRuntimeDiagnosticEnvelope(
              runtimeId: candidate.id,
              runtimeName: candidate.name,
              summary: 'The LiteRT-LM package could not be prepared.',
              detail:
                  'The local model did not complete initialization or warmup successfully.',
              deviceLabel: resolvedDeviceLabel,
              platformLabel: platformLabel,
              reasonCode: 'warmup_failed',
              repairActions: const [
                'Retry initialization.',
                'Re-download the package if it appears corrupted.',
                'Choose a different runtime if the issue persists.',
              ],
            ),
          );
        }

        if (candidate.opensModelManager) {
          return AssistantRuntimePreparationResult.blocked(
            AssistantRuntimeDiagnosticEnvelope(
              runtimeId: candidate.id,
              runtimeName: candidate.name,
              summary: 'The selected package is not installed yet.',
              detail:
                  'This runtime cannot initialize until its local package has been downloaded.',
              deviceLabel: resolvedDeviceLabel,
              platformLabel: platformLabel,
              reasonCode: 'package_missing',
              repairActions: const [
                'Open Profile > AI Models and download the package.',
              ],
            ),
          );
        }
    }

    final readyCancel = cancelled();
    if (readyCancel != null) return readyCancel;
    emit(
      AssistantRuntimePreparationPhase.ready,
      1,
      'Runtime ready',
      '${candidate.name} finished its local preflight and is ready to launch.',
    );
    return AssistantRuntimePreparationResult.ready();
  }

  Future<String> generateText({
    required String? selectedModelId,
    required String prompt,
    String? systemPrompt,
  }) async {
    final runtimeId = _requireSelectedRuntime(selectedModelId);
    final fullPrompt = _withSystemPrompt(prompt, systemPrompt);

    switch (runtimeId) {
      case geminiNanoAssistantModelId:
        await _ensureGeminiNanoReady();
        return _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateGeminiNanoTextOverride?.call(fullPrompt) ??
              _geminiNano.generateContentStrict(fullPrompt)),
          geminiNanoInitializationFailedMessage,
        );

      case litertGemmaAssistantModelId:
        return _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateLiteRtTextOverride?.call(
                prompt,
                systemPrompt: systemPrompt,
              ) ??
              _liteRtLm.generateText(prompt, systemPrompt: systemPrompt)),
          litertGemmaUnavailableMessage,
        );

      case geminiCloudAssistantModelId:
        await (_initializeCloudOverride?.call() ?? _geminiCloud.initialize());
        final isAvailable =
            _isCloudAvailableOverride?.call() ?? _geminiCloud.isAvailable;
        if (!isAvailable) {
          throw AssistantRuntimeUnavailableException(
            runtimeId,
            geminiCloudUnavailableMessage,
          );
        }
        return _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateCloudTextOverride?.call(fullPrompt) ??
              _geminiCloud.generateText(fullPrompt)),
          geminiCloudEmptyResponseMessage,
        );

      default:
        final offlineModelId = offlineModelIdFromAssistantModelId(runtimeId);
        if (offlineModelId == null) {
          throw AssistantRuntimeUnavailableException(
            runtimeId,
            unsupportedAssistantRuntimeMessage,
          );
        }
        final package = await _resolveOfflinePackage(runtimeId);
        return _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateLiteRtModelTextOverride?.call(
                package,
                prompt,
                systemPrompt: systemPrompt,
              ) ??
              _liteRtLm.generateTextForModel(
                package,
                prompt,
                systemPrompt: systemPrompt,
              )),
          offlinePackageUnavailableMessage,
        );
    }
  }

  Stream<String> generateTextStream({
    required String? selectedModelId,
    required String prompt,
  }) async* {
    final runtimeId = _requireSelectedRuntime(selectedModelId);

    if (runtimeId != geminiNanoAssistantModelId) {
      yield await generateText(selectedModelId: runtimeId, prompt: prompt);
      return;
    }

    await _ensureGeminiNanoReady();
    var yielded = false;
    final stream =
        _generateGeminiNanoStreamOverride?.call(prompt) ??
        _geminiNano.generateContentStreamStrict(prompt);
    await for (final chunk in stream) {
      if (chunk.trim().isEmpty) continue;
      yielded = true;
      yield chunk;
    }
    if (!yielded) {
      throw AssistantRuntimeUnavailableException(
        runtimeId,
        geminiNanoInitializationFailedMessage,
      );
    }
  }

  Future<void> _ensureGeminiNanoReady() async {
    final supported =
        await (_isGeminiNanoSupportedOverride?.call() ??
            _geminiNano.isSupported());
    if (!supported) {
      throw AssistantRuntimeUnavailableException(
        geminiNanoAssistantModelId,
        geminiNanoUnavailableMessage,
      );
    }

    if (_geminiNano.isInitialized && _initializeGeminiNanoOverride == null) {
      return;
    }

    final initialized =
        await (_initializeGeminiNanoOverride?.call() ??
            _geminiNano.initialize());
    if (!initialized) {
      throw AssistantRuntimeUnavailableException(
        geminiNanoAssistantModelId,
        geminiNanoInitializationFailedMessage,
      );
    }
  }

  String _requireSelectedRuntime(String? selectedModelId) {
    final runtimeId = selectedModelId?.trim();
    if (runtimeId == null || runtimeId.isEmpty) {
      throw AssistantRuntimeUnavailableException(
        null,
        noAssistantModelSelectedMessage,
      );
    }
    return runtimeId;
  }

  String _withSystemPrompt(String prompt, String? systemPrompt) {
    final trimmedSystemPrompt = systemPrompt?.trim();
    if (trimmedSystemPrompt == null || trimmedSystemPrompt.isEmpty) {
      return prompt;
    }
    return '$trimmedSystemPrompt\n\n$prompt';
  }

  String _nonEmptyOrUnavailable(
    String runtimeId,
    String? text,
    String message,
  ) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      throw AssistantRuntimeUnavailableException(runtimeId, message);
    }
    return trimmed;
  }

  Future<OfflineModelInfo> _resolveOfflinePackage(String runtimeId) async {
    final library =
        await (_loadAssistantModelLibraryOverride?.call() ??
            AssistantModelLibraryState.load(task: AssistantTask.chat));
    final package = library.candidateById(runtimeId)?.package;
    if (package == null) {
      throw AssistantRuntimeUnavailableException(
        runtimeId,
        offlinePackageCatalogMissingMessage,
      );
    }
    return package;
  }

  Future<ModelCompatibilityResult> _checkCompatibility(
    OfflineModelInfo package,
  ) async {
    final registry = ModelRegistry()..registerModel(package);
    return registry.checkCompatibility(package);
  }
}
