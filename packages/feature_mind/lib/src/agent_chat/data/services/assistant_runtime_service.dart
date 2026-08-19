import '../../../services/gguf_load_diagnostics.dart';
import '../../../services/llama_gguf_service.dart';
import 'package:flutter/foundation.dart';
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
typedef RuntimeDebugTraceEmitter =
    void Function(AssistantRuntimeDebugTrace trace);

@immutable
class AssistantRuntimeDebugTrace {
  const AssistantRuntimeDebugTrace({
    required this.runtimeId,
    required this.stage,
    required this.recordedAt,
    this.systemPromptPreview,
    this.promptPreview,
    this.responsePreview,
    this.detail,
  });

  final String runtimeId;
  final String stage;
  final DateTime recordedAt;
  final String? systemPromptPreview;
  final String? promptPreview;
  final String? responsePreview;
  final String? detail;
}

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

class AssistantRuntimeFallbackDecision {
  const AssistantRuntimeFallbackDecision({
    required this.failedRuntimeId,
    required this.failedRuntimeName,
    required this.fallbackRuntimeId,
    required this.fallbackRuntimeName,
    required this.reason,
  });

  final String failedRuntimeId;
  final String failedRuntimeName;
  final String fallbackRuntimeId;
  final String fallbackRuntimeName;
  final String reason;
}

class AssistantRuntimeService {
  AssistantRuntimeService({
    GeminiNanoService? geminiNano,
    LiteRtLmService? liteRtLm,
    LlamaGgufService? llamaGguf,
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
    this._debugTraceEmitter,
  }) : _geminiNano = geminiNano ?? GeminiNanoService(),
       _liteRtLm = liteRtLm ?? LiteRtLmService(),
       _llamaGguf = llamaGguf ?? LlamaGgufService(),
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
  final LlamaGgufService _llamaGguf;
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
  final RuntimeDebugTraceEmitter? _debugTraceEmitter;

  Future<AssistantRuntimePreparationResult> prepareRuntime({
    required AssistantModelCandidate candidate,
    int? contextLengthOverride,
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
    final platformLabel = _resolvePlatformLabel(deviceInfo);
    final isMacLike = platformLabel.contains('MAC');
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

    final readiness = candidate.readiness;
    if (readiness != null && !readiness.canPrepare) {
      return AssistantRuntimePreparationResult.blocked(
        AssistantRuntimeDiagnosticEnvelope(
          runtimeId: candidate.id,
          runtimeName: candidate.name,
          summary: readiness.headline,
          detail: readiness.detail,
          deviceLabel: resolvedDeviceLabel,
          platformLabel: platformLabel,
          reasonCode: 'runtime_unavailable',
          repairActions: _repairActionsForReadiness(
            readiness,
            platformLabel: platformLabel,
            package: candidate.package,
          ),
        ),
      );
    }

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
        // Warmup is the longest step, so it is where cancellation usually
        // lands. Re-check before reporting ready, the same way the shared tail
        // below does, or a cancelled setup still launches the runtime.
        final postWarmupCancel = cancelled();
        if (postWarmupCancel != null) return postWarmupCancel;
        emit(
          AssistantRuntimePreparationPhase.ready,
          1,
          'Runtime ready',
          '${candidate.name} finished its local preflight and is ready to launch.',
        );
        return AssistantRuntimePreparationResult.ready();

      case litertGemmaAssistantModelId:
      default:
        final offlineModelId = offlineModelIdFromAssistantModelId(candidate.id);
        if (offlineModelId != null &&
            candidate.id != litertGemmaAssistantModelId) {
          final package =
              candidate.package ??
              await _resolveOfflinePackageOrNull(candidate.id);
          if (package == null || !package.isDownloaded) {
            return AssistantRuntimePreparationResult.blocked(
              AssistantRuntimeDiagnosticEnvelope(
                runtimeId: candidate.id,
                runtimeName: candidate.name,
                summary: 'The selected GGUF model is not installed.',
                detail: 'A valid local model path is required before loading.',
                deviceLabel: resolvedDeviceLabel,
                platformLabel: platformLabel,
                reasonCode: 'model_missing',
                repairActions: const [
                  'Download the model from Profile > AI Models.',
                  'Verify the model file before trying again.',
                  'Choose another installed local model.',
                ],
              ),
            );
          }
          if (!await _llamaGguf.isAvailable()) {
            return AssistantRuntimePreparationResult.blocked(
              AssistantRuntimeDiagnosticEnvelope(
                runtimeId: candidate.id,
                runtimeName: candidate.name,
                summary: 'The native GGUF backend is unavailable.',
                detail: isMacLike
                    ? 'The Airo Mind llama.cpp engine could not start. Restart the app or verify the model file in Application Support.'
                    : 'The llama.cpp backend is unavailable, so this device cannot load the selected GGUF model locally.',
                deviceLabel: resolvedDeviceLabel,
                platformLabel: platformLabel,
                reasonCode: 'native_backend_unavailable',
                repairActions: isMacLike
                    ? const [
                        'Open Models and confirm Qwen GGUF is installed.',
                        'Restart Airo Mind after models finish installing.',
                        'Pick another downloaded GGUF package.',
                      ]
                    : const [
                        'Choose a LiteRT-LM package.',
                        'Configure a compatible remote llama.cpp server.',
                        'Retry after restarting the app.',
                      ],
              ),
            );
          }
          emit(
            AssistantRuntimePreparationPhase.allocate,
            0.4,
            'Load local model',
            'Mapping the verified GGUF artifact into the native runtime.',
          );
          final loadCancel = cancelled();
          if (loadCancel != null) return loadCancel;
          final contextSize = _effectiveContextLength(
            package,
            contextLengthOverride: contextLengthOverride,
          );
          final loaded = await _llamaGguf.loadModelOutcome(
            package,
            contextSize: contextSize,
          );
          if (!loaded.succeeded) {
            final copy = GgufLoadDiagnostics.describe(
              model: package,
              outcome: loaded,
              isMacLike: isMacLike,
            );
            return AssistantRuntimePreparationResult.blocked(
              AssistantRuntimeDiagnosticEnvelope(
                runtimeId: candidate.id,
                runtimeName: candidate.name,
                summary: copy.summary,
                detail: copy.detail,
                deviceLabel: resolvedDeviceLabel,
                platformLabel: platformLabel,
                reasonCode: copy.reasonCode,
                repairActions: copy.repairActions,
              ),
            );
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
        final downloadedPackage = await _resolveDownloadedLiteRtPackage(
          candidate.id,
          preferredPackage: candidate.package,
        );
        final package = downloadedPackage ?? candidate.package;
        if (package != null &&
            !AssistantModelLibraryState.isLiteRtPackage(package)) {
          return AssistantRuntimePreparationResult.blocked(
            AssistantRuntimeDiagnosticEnvelope(
              runtimeId: candidate.id,
              runtimeName: candidate.name,
              summary: 'This GGUF package cannot run in the local adapter.',
              detail:
                  'The native llama.cpp backend is not bundled, so a downloaded GGUF file must not be routed through LiteRT-LM.',
              deviceLabel: resolvedDeviceLabel,
              platformLabel: platformLabel,
              reasonCode: 'native_backend_unavailable',
              repairActions: const [
                'Configure an OpenAI-compatible llama.cpp, Ollama, or LM Studio server.',
                'Choose a LiteRT-LM package from Model Management.',
              ],
            ),
          );
        }
        final runtimeReportedAvailable =
            await (_isLiteRtAvailableOverride?.call() ??
                _liteRtLm.isAvailable());
        // A native channel or configured download URL is not a runnable model.
        // Default LiteRT startup requires either a verified package path or an
        // explicit local artifact path. Test overrides remain explicit and can
        // model a ready backend without depending on device storage.
        final available =
            (downloadedPackage?.filePath?.trim().isNotEmpty ?? false) ||
            (runtimeReportedAvailable &&
                (_isLiteRtAvailableOverride != null ||
                    _liteRtLm.hasConfiguredModelPath));
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
                'Set LITERT_LM_MODEL_PATH to a verified local artifact when launching locally.',
              ],
            ),
          );
        }

        if (package != null) {
          final compatibilityPackage = _packageWithContextOverride(
            package,
            contextLengthOverride: contextLengthOverride,
          );
          final compatibility =
              await (_checkModelCompatibilityOverride?.call(
                    compatibilityPackage,
                  ) ??
                  _checkCompatibility(compatibilityPackage));
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
        final selectedPackage = downloadedPackage ?? package;
        final preparedPackage = selectedPackage == null
            ? null
            : _packageWithContextOverride(
                selectedPackage,
                contextLengthOverride: contextLengthOverride,
              );
        final warmed = preparedPackage != null
            ? await (_warmupLiteRtModelOverride?.call(preparedPackage) ??
                  _liteRtLm.warmupModel(preparedPackage))
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
    _emitDebugTrace(
      AssistantRuntimeDebugTrace(
        runtimeId: runtimeId,
        stage: 'request',
        recordedAt: DateTime.now(),
        systemPromptPreview: _previewText(systemPrompt),
        promptPreview: _previewText(prompt),
        detail: 'generateText',
      ),
    );

    switch (runtimeId) {
      case geminiNanoAssistantModelId:
        await _ensureGeminiNanoReady();
        final response = _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateGeminiNanoTextOverride?.call(fullPrompt) ??
              _geminiNano.generateContentStrict(fullPrompt)),
          geminiNanoInitializationFailedMessage,
        );
        _emitResponseTrace(runtimeId, response, detail: 'generateText');
        return response;

      case litertGemmaAssistantModelId:
        final package = await _resolveDownloadedLiteRtPackage(runtimeId);
        if (package != null) {
          final response = _nonEmptyOrUnavailable(
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
            kIsWeb
                ? litertWebRuntimeInitFailedMessage
                : litertGemmaUnavailableMessage,
          );
          _emitResponseTrace(runtimeId, response, detail: package.id);
          return response;
        }
        final response = _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateLiteRtTextOverride?.call(
                prompt,
                systemPrompt: systemPrompt,
              ) ??
              _liteRtLm.generateText(prompt, systemPrompt: systemPrompt)),
          litertGemmaUnavailableMessage,
        );
        _emitResponseTrace(runtimeId, response, detail: 'default-litert');
        return response;

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
        final response = _nonEmptyOrUnavailable(
          runtimeId,
          await (_generateCloudTextOverride?.call(fullPrompt) ??
              _geminiCloud.generateText(fullPrompt)),
          geminiCloudEmptyResponseMessage,
        );
        _emitResponseTrace(runtimeId, response, detail: 'generateText');
        return response;

      default:
        final offlineModelId = offlineModelIdFromAssistantModelId(runtimeId);
        if (offlineModelId == null) {
          throw AssistantRuntimeUnavailableException(
            runtimeId,
            unsupportedAssistantRuntimeMessage,
          );
        }
        final package = await _resolveOfflinePackage(runtimeId);
        if (!AssistantModelLibraryState.isLiteRtPackage(package)) {
          if (!await _llamaGguf.isAvailable()) {
            throw AssistantRuntimeUnavailableException(
              runtimeId,
              'This GGUF package is installed, but the native llama.cpp backend is unavailable on this device.',
            );
          }
          final responseBuffer = StringBuffer();
          await for (final chunk in _llamaGguf.generate(
            prompt: fullPrompt,
            maxTokens: 512,
          )) {
            responseBuffer.write(chunk);
          }
          final response = _nonEmptyOrUnavailable(
            runtimeId,
            responseBuffer.toString(),
            offlinePackageUnavailableMessage,
          );
          _emitResponseTrace(runtimeId, response, detail: package.id);
          return response;
        }
        final response = _nonEmptyOrUnavailable(
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
        _emitResponseTrace(runtimeId, response, detail: package.id);
        return response;
    }
  }

  Stream<String> generateTextStream({
    required String? selectedModelId,
    required String prompt,
    String? systemPrompt,
  }) async* {
    final runtimeId = _requireSelectedRuntime(selectedModelId);

    if (runtimeId != geminiNanoAssistantModelId) {
      yield await generateText(
        selectedModelId: runtimeId,
        prompt: prompt,
        systemPrompt: systemPrompt,
      );
      return;
    }

    _emitDebugTrace(
      AssistantRuntimeDebugTrace(
        runtimeId: runtimeId,
        stage: 'request',
        recordedAt: DateTime.now(),
        systemPromptPreview: _previewText(systemPrompt),
        promptPreview: _previewText(prompt),
        detail: 'generateTextStream',
      ),
    );

    await _ensureGeminiNanoReady();
    var yielded = false;
    final stream =
        _generateGeminiNanoStreamOverride?.call(
          _withSystemPrompt(prompt, systemPrompt),
        ) ??
        _geminiNano.generateContentStreamStrict(
          _withSystemPrompt(prompt, systemPrompt),
        );
    await for (final chunk in stream) {
      if (chunk.trim().isEmpty) continue;
      yielded = true;
      _emitResponseTrace(runtimeId, chunk, detail: 'stream-chunk');
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
    final package = await _resolveOfflinePackageOrNull(runtimeId);
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

  OfflineModelInfo _packageWithContextOverride(
    OfflineModelInfo package, {
    int? contextLengthOverride,
  }) {
    final contextLength = _effectiveContextLength(
      package,
      contextLengthOverride: contextLengthOverride,
    );
    if (contextLength == package.contextLength) {
      return package;
    }
    return package.copyWith(contextLength: contextLength);
  }

  int _effectiveContextLength(
    OfflineModelInfo package, {
    int? contextLengthOverride,
  }) {
    final requested = contextLengthOverride ?? package.contextLength;
    return requested.clamp(512, 8192).toInt();
  }

  Future<OfflineModelInfo?> _resolveDownloadedLiteRtPackage(
    String runtimeId, {
    OfflineModelInfo? preferredPackage,
  }) async {
    if (runtimeId != litertGemmaAssistantModelId) {
      return null;
    }

    final package =
        preferredPackage ?? await _resolveOfflinePackageOrNull(runtimeId);
    if (package == null || !package.isDownloaded) {
      return null;
    }
    return package;
  }

  Future<OfflineModelInfo?> _resolveOfflinePackageOrNull(
    String runtimeId,
  ) async {
    try {
      final library =
          await (_loadAssistantModelLibraryOverride?.call() ??
              AssistantModelLibraryState.load(task: AssistantTask.chat));
      return library.candidateById(runtimeId)?.package;
    } catch (_) {
      return null;
    }
  }

  void _emitResponseTrace(String runtimeId, String response, {String? detail}) {
    _emitDebugTrace(
      AssistantRuntimeDebugTrace(
        runtimeId: runtimeId,
        stage: 'response',
        recordedAt: DateTime.now(),
        responsePreview: _previewText(response),
        detail: detail,
      ),
    );
  }

  void _emitDebugTrace(AssistantRuntimeDebugTrace trace) {
    _debugTraceEmitter?.call(trace);
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[AssistantRuntimeTrace] runtime=${trace.runtimeId} '
      'stage=${trace.stage} detail=${trace.detail ?? '-'} '
      'system=${trace.systemPromptPreview ?? '-'} '
      'prompt=${trace.promptPreview ?? '-'} '
      'response=${trace.responsePreview ?? '-'}',
    );
  }

  String? _previewText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 220) {
      return normalized;
    }
    return '${normalized.substring(0, 220)}...';
  }

  Future<AssistantRuntimeFallbackDecision?> resolveFallback({
    required String failedRuntimeId,
    AssistantTask task = AssistantTask.chat,
    Set<String> excludedRuntimeIds = const {},
    String? reason,
  }) async {
    final library =
        await (_loadAssistantModelLibraryOverride?.call() ??
            AssistantModelLibraryState.load(task: task));

    final failedCandidate = library.candidateById(failedRuntimeId);
    final orderedCandidates = <AssistantModelCandidate>[
      library.recommendedFor(task),
      ...library.candidates,
    ];
    final seen = <String>{...excludedRuntimeIds, failedRuntimeId};

    for (final candidate in orderedCandidates) {
      if (!seen.add(candidate.id) || !candidate.available) {
        continue;
      }
      return AssistantRuntimeFallbackDecision(
        failedRuntimeId: failedRuntimeId,
        failedRuntimeName: failedCandidate?.name ?? failedRuntimeId,
        fallbackRuntimeId: candidate.id,
        fallbackRuntimeName: candidate.name,
        reason:
            reason ??
            'the selected runtime is unavailable on this device right now',
      );
    }

    return null;
  }

  static String _resolvePlatformLabel(Map<String, dynamic> deviceInfo) {
    final reported =
        (deviceInfo['platform'] as String?)?.trim().toUpperCase() ?? '';
    if (reported.isNotEmpty && reported != 'DEVICE') {
      return reported;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => 'MACOS',
      TargetPlatform.windows => 'WINDOWS',
      TargetPlatform.linux => 'LINUX',
      TargetPlatform.android => 'ANDROID',
      TargetPlatform.iOS => 'IOS',
      TargetPlatform.fuchsia => 'FUCHSIA',
    };
  }

  static List<String> _repairActionsForReadiness(
    ModelReadinessState readiness, {
    required String platformLabel,
    OfflineModelInfo? package,
  }) {
    final runtime = package?.effectiveRuntime;
    final isMacLike = platformLabel.toUpperCase().contains('MAC');
    if (runtime == InferenceRuntime.litertLm) {
      if (isMacLike) {
        return const [
          'Download a GGUF model (for example Qwen 1.5B) from AI Models.',
          'Choose the GGUF package in Mind chat.',
          'Use Gemini Cloud if you prefer a hosted model.',
        ];
      }
      return const [
        'Install this package on a supported Android device.',
        'Choose a GGUF or cloud model on desktop.',
      ];
    }
    if (runtime == InferenceRuntime.llamaCpp) {
      return const [
        'Verify the native llama.cpp backend is available on this device.',
        'Re-download the GGUF artifact if it appears corrupted.',
        'Configure a compatible remote llama.cpp server.',
      ];
    }
    return const [
      'Open AI Models and choose a package supported on this device.',
      'Pick another model from the library.',
    ];
  }
}
