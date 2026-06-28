import 'dart:async';

import 'package:meta/meta.dart';

import '../residency/model_residency_manager.dart';

enum ModelPreloadEntryStatus { warmed, skipped, failed }

@immutable
class ModelPreloadReportEntry {
  const ModelPreloadReportEntry({
    required this.runtimeId,
    required this.residentType,
    required this.status,
    required this.reason,
    required this.duration,
  });

  final String runtimeId;
  final ResidentRuntimeType residentType;
  final ModelPreloadEntryStatus status;
  final String reason;
  final Duration duration;
}

@immutable
class ModelPreloadReport {
  const ModelPreloadReport({
    required this.entries,
    required this.startedAt,
    required this.finishedAt,
    required this.aborted,
  });

  final List<ModelPreloadReportEntry> entries;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool aborted;
}

abstract class ModelWarmupAdapter {
  ModelResidentSpec get residentSpec;

  Future<bool> isAvailable();

  Future<bool> warmup();
}

class NoOpWarmupAdapter implements ModelWarmupAdapter {
  NoOpWarmupAdapter(this.residentSpec, {this.available = false});

  @override
  final ModelResidentSpec residentSpec;

  final bool available;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> warmup() async => available;
}

typedef ActiveGenerationCheck = bool Function();

class ModelPreloader {
  ModelPreloader({required this._residencyManager, this._isGenerationActive});

  final ModelResidencyManager _residencyManager;
  final ActiveGenerationCheck? _isGenerationActive;
  bool _abortRequested = false;

  void abortPreload() {
    _abortRequested = true;
  }

  Future<ModelPreloadReport> preloadSelectedModels({
    required List<ModelWarmupAdapter> adapters,
  }) async {
    _abortRequested = false;
    final startedAt = DateTime.now();
    final entries = <ModelPreloadReportEntry>[];
    var aborted = false;

    final orderedAdapters = [...adapters]
      ..sort(
        (left, right) => _typeOrder(
          left.residentSpec.residentType,
        ).compareTo(_typeOrder(right.residentSpec.residentType)),
      );

    for (final adapter in orderedAdapters) {
      final stepStartedAt = DateTime.now();
      final resident = adapter.residentSpec;

      if (_abortRequested) {
        aborted = true;
        entries.add(
          ModelPreloadReportEntry(
            runtimeId: resident.id,
            residentType: resident.residentType,
            status: ModelPreloadEntryStatus.skipped,
            reason: 'aborted',
            duration: DateTime.now().difference(stepStartedAt),
          ),
        );
        continue;
      }

      if (_isGenerationActive?.call() ?? false) {
        aborted = true;
        entries.add(
          ModelPreloadReportEntry(
            runtimeId: resident.id,
            residentType: resident.residentType,
            status: ModelPreloadEntryStatus.skipped,
            reason: 'generation_active',
            duration: DateTime.now().difference(stepStartedAt),
          ),
        );
        continue;
      }

      if (resident.residentType == ResidentRuntimeType.image) {
        entries.add(
          ModelPreloadReportEntry(
            runtimeId: resident.id,
            residentType: resident.residentType,
            status: ModelPreloadEntryStatus.skipped,
            reason: 'image_models_preload_disabled',
            duration: DateTime.now().difference(stepStartedAt),
          ),
        );
        continue;
      }

      final available = await adapter.isAvailable();
      if (!available) {
        entries.add(
          ModelPreloadReportEntry(
            runtimeId: resident.id,
            residentType: resident.residentType,
            status: ModelPreloadEntryStatus.skipped,
            reason: 'runtime_unavailable',
            duration: DateTime.now().difference(stepStartedAt),
          ),
        );
        continue;
      }

      final canLoadWithoutEviction = await _residencyManager
          .canLoadWithoutEviction(resident);
      if (!canLoadWithoutEviction) {
        entries.add(
          ModelPreloadReportEntry(
            runtimeId: resident.id,
            residentType: resident.residentType,
            status: ModelPreloadEntryStatus.skipped,
            reason: 'would_require_eviction',
            duration: DateTime.now().difference(stepStartedAt),
          ),
        );
        continue;
      }

      final result = await _residencyManager.ensureResident(
        resident,
        allowEviction: false,
        onLoad: adapter.warmup,
      );
      final status = switch (result.status) {
        EnsureResidentStatus.loaded ||
        EnsureResidentStatus.alreadyResident => ModelPreloadEntryStatus.warmed,
        EnsureResidentStatus.blocked => ModelPreloadEntryStatus.skipped,
        EnsureResidentStatus.failed => ModelPreloadEntryStatus.failed,
      };
      final reason = switch (result.status) {
        EnsureResidentStatus.loaded => 'warmed',
        EnsureResidentStatus.alreadyResident => 'already_resident',
        EnsureResidentStatus.blocked => 'would_require_eviction',
        EnsureResidentStatus.failed => 'warmup_failed',
      };
      entries.add(
        ModelPreloadReportEntry(
          runtimeId: resident.id,
          residentType: resident.residentType,
          status: status,
          reason: reason,
          duration: DateTime.now().difference(stepStartedAt),
        ),
      );
    }

    return ModelPreloadReport(
      entries: entries,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      aborted: aborted,
    );
  }

  int _typeOrder(ResidentRuntimeType type) {
    switch (type) {
      case ResidentRuntimeType.text:
        return 0;
      case ResidentRuntimeType.tts:
        return 1;
      case ResidentRuntimeType.stt:
        return 2;
      case ResidentRuntimeType.classifier:
        return 3;
      case ResidentRuntimeType.image:
        return 4;
    }
  }
}
