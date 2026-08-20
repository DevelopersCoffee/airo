import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../host/assistant_host_adapter.dart';
import '../data/services/assistant_runtime_service.dart';
import '../presentation/screens/model_library_screen.dart';
import 'assistant_model_preferences.dart';

/// Where the selected assistant runtime sits in the prepare/warm pipeline.
enum AssistantRuntimeReadinessPhase {
  idle,
  loading,
  warming,
  ready,
  blocked,
  error,
}

/// User-visible readiness for the assistant chat composer.
///
/// Mirrors on-device AI gallery apps: load → warm → ready, with an explicit
/// percentage so people know why Send stays disabled.
class AssistantRuntimeReadiness {
  const AssistantRuntimeReadiness({
    required this.phase,
    required this.progress,
    required this.label,
    this.detail = '',
    this.canSend = false,
  });

  const AssistantRuntimeReadiness.idle()
    : phase = AssistantRuntimeReadinessPhase.idle,
      progress = 0,
      label = 'Choose a model',
      detail = 'Pick a local model before sending messages.',
      canSend = false;

  final AssistantRuntimeReadinessPhase phase;
  final double progress;
  final String label;
  final String detail;

  /// True only when weights are loaded and warmed for the selected runtime.
  final bool canSend;
}

final assistantRuntimeReadinessProvider =
    StateNotifierProvider<
      AssistantRuntimeReadinessNotifier,
      AssistantRuntimeReadiness
    >((ref) {
      return AssistantRuntimeReadinessNotifier(ref);
    });

class AssistantRuntimeReadinessNotifier
    extends StateNotifier<AssistantRuntimeReadiness> {
  AssistantRuntimeReadinessNotifier(this._ref)
    : super(const AssistantRuntimeReadiness.idle()) {
    _ref.listen<String?>(selectedAssistantModelIdProvider, (_, next) {
      unawaited(_sync(next));
    });
    unawaited(_sync(_ref.read(selectedAssistantModelIdProvider)));
  }

  final Ref _ref;
  int _generation = 0;

  Future<void> _sync(String? assistantModelId) async {
    final generation = ++_generation;

    if (assistantModelId == null) {
      state = const AssistantRuntimeReadiness.idle();
      return;
    }

    final library = await _ref.read(assistantModelLibraryProvider.future);
    if (generation != _generation) return;

    final candidate = library.candidateById(assistantModelId);
    if (candidate == null) {
      state = const AssistantRuntimeReadiness(
        phase: AssistantRuntimeReadinessPhase.blocked,
        progress: 0,
        label: 'Model unavailable',
        detail: 'Pick another model from the library.',
        canSend: false,
      );
      return;
    }

    if (!candidate.local) {
      state = AssistantRuntimeReadiness(
        phase: AssistantRuntimeReadinessPhase.ready,
        progress: 1,
        label: '${candidate.name} ready',
        detail: candidate.description,
        canSend: candidate.available,
      );
      return;
    }

    final readiness = candidate.readiness;
    if (readiness != null && !readiness.canPrepare) {
      state = AssistantRuntimeReadiness(
        phase: AssistantRuntimeReadinessPhase.blocked,
        progress: 0,
        label: readiness.headline,
        detail: readiness.detail,
        canSend: false,
      );
      return;
    }

    if (!candidate.available) {
      state = AssistantRuntimeReadiness(
        phase: AssistantRuntimeReadinessPhase.blocked,
        progress: 0,
        label: readiness?.headline ?? 'Download required',
        detail: readiness?.detail ?? candidate.actionLabel,
        canSend: false,
      );
      return;
    }

    state = AssistantRuntimeReadiness(
      phase: AssistantRuntimeReadinessPhase.loading,
      progress: 0.05,
      label: 'Preparing ${candidate.name}',
      detail: 'Loading and warming weights on device…',
      canSend: false,
    );

    final runtimeService = AssistantRuntimeService();
    final result = await runtimeService.prepareRuntime(
      candidate: candidate,
      contextLengthOverride: _ref
          .read(assistantHostAdapterProvider)
          .modelContextLength,
      onProgress: (value) {
        if (generation != _generation) return;
        final phase = switch (value.phase) {
          AssistantRuntimePreparationPhase.validate ||
          AssistantRuntimePreparationPhase.allocate ||
          AssistantRuntimePreparationPhase.load =>
            AssistantRuntimeReadinessPhase.loading,
          AssistantRuntimePreparationPhase.warmup =>
            AssistantRuntimeReadinessPhase.warming,
          AssistantRuntimePreparationPhase.ready =>
            AssistantRuntimeReadinessPhase.ready,
        };
        state = AssistantRuntimeReadiness(
          phase: phase,
          progress: value.progress,
          label: value.label,
          detail: value.detail,
          canSend: phase == AssistantRuntimeReadinessPhase.ready,
        );
      },
    );

    if (generation != _generation) return;

    if (result.status == AssistantRuntimePreparationStatus.ready) {
      state = AssistantRuntimeReadiness(
        phase: AssistantRuntimeReadinessPhase.ready,
        progress: 1,
        label: '${candidate.name} ready',
        detail: 'You can send messages now.',
        canSend: true,
      );
      return;
    }

    state = AssistantRuntimeReadiness(
      phase: AssistantRuntimeReadinessPhase.blocked,
      progress: 0,
      label:
          result.diagnostic?.summary ?? 'Could not prepare ${candidate.name}',
      detail:
          result.diagnostic?.detail ??
          'Try another model or open Models to repair the download.',
      canSend: false,
    );
  }

  Future<void> refresh() => _sync(_ref.read(selectedAssistantModelIdProvider));
}
