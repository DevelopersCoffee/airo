import 'dart:async';

import 'package:meta/meta.dart';

import '../device/memory_budget_manager.dart';

enum ResidentRuntimeType { text, image, stt, tts, classifier }

@immutable
class ModelResidentSpec {
  const ModelResidentSpec({
    required this.id,
    required this.residentType,
    required this.estimatedMemoryBytes,
    this.pinned = false,
    this.sidecar = false,
  });

  final String id;
  final ResidentRuntimeType residentType;
  final int estimatedMemoryBytes;
  final bool pinned;
  final bool sidecar;

  bool get isGenerationModel =>
      residentType == ResidentRuntimeType.text ||
      residentType == ResidentRuntimeType.image;
}

@immutable
class ModelResidencyPlanResult {
  const ModelResidencyPlanResult({
    required this.incoming,
    required this.budgetBytes,
    required this.currentUsageBytes,
    required this.projectedUsageBytes,
    required this.residentsToEvict,
    required this.fits,
    this.refusalReason,
  });

  final ModelResidentSpec incoming;
  final int budgetBytes;
  final int currentUsageBytes;
  final int projectedUsageBytes;
  final List<ModelResidentSpec> residentsToEvict;
  final bool fits;
  final String? refusalReason;
}

class ModelResidencyPolicy {
  const ModelResidencyPolicy();

  ModelResidencyPlanResult plan({
    required List<ModelResidentSpec> currentResidents,
    required ModelResidentSpec incoming,
    required int budgetBytes,
  }) {
    final currentUsageBytes = currentResidents.fold<int>(
      0,
      (sum, resident) => sum + resident.estimatedMemoryBytes,
    );
    final projectedUsageBytes =
        currentUsageBytes + incoming.estimatedMemoryBytes;

    if (projectedUsageBytes <= budgetBytes) {
      return ModelResidencyPlanResult(
        incoming: incoming,
        budgetBytes: budgetBytes,
        currentUsageBytes: currentUsageBytes,
        projectedUsageBytes: projectedUsageBytes,
        residentsToEvict: const [],
        fits: true,
      );
    }

    final candidates = [...currentResidents]
      ..sort(
        (left, right) => _evictionPriority(
          left,
          incoming,
        ).compareTo(_evictionPriority(right, incoming)),
      );

    final evictions = <ModelResidentSpec>[];
    var reclaimedBytes = 0;

    for (final resident in candidates) {
      if (resident.pinned) {
        continue;
      }

      evictions.add(resident);
      reclaimedBytes += resident.estimatedMemoryBytes;

      if (projectedUsageBytes - reclaimedBytes <= budgetBytes) {
        return ModelResidencyPlanResult(
          incoming: incoming,
          budgetBytes: budgetBytes,
          currentUsageBytes: currentUsageBytes,
          projectedUsageBytes: projectedUsageBytes - reclaimedBytes,
          residentsToEvict: evictions,
          fits: true,
        );
      }
    }

    return ModelResidencyPlanResult(
      incoming: incoming,
      budgetBytes: budgetBytes,
      currentUsageBytes: currentUsageBytes,
      projectedUsageBytes: projectedUsageBytes - reclaimedBytes,
      residentsToEvict: evictions,
      fits: false,
      refusalReason:
          'Incoming runtime does not fit within the current device budget.',
    );
  }

  int _evictionPriority(
    ModelResidentSpec resident,
    ModelResidentSpec incoming,
  ) {
    if (_isOppositeGenerationModel(resident, incoming)) {
      return 0;
    }
    if (resident.sidecar) {
      return 2;
    }
    if (resident.pinned) {
      return 3;
    }
    return 1;
  }

  bool _isOppositeGenerationModel(
    ModelResidentSpec resident,
    ModelResidentSpec incoming,
  ) {
    if (!resident.isGenerationModel || !incoming.isGenerationModel) {
      return false;
    }

    return resident.residentType != incoming.residentType;
  }
}

enum EnsureResidentStatus { loaded, alreadyResident, blocked, failed }

@immutable
class EnsureResidentResult {
  const EnsureResidentResult({
    required this.status,
    required this.spec,
    this.plan,
  });

  final EnsureResidentStatus status;
  final ModelResidentSpec spec;
  final ModelResidencyPlanResult? plan;
}

typedef ResidencyBudgetLoader = Future<int> Function();
typedef ResidentEvictionCallback =
    Future<void> Function(ModelResidentSpec resident);
typedef ResidentLoadCallback = Future<bool> Function();

class ModelResidencyManager {
  ModelResidencyManager({
    ResidencyBudgetLoader? loadBudgetBytes,
    ModelResidencyPolicy policy = const ModelResidencyPolicy(),
  }) : _loadBudgetBytes = loadBudgetBytes ?? _defaultBudgetBytes,
       _policy = policy;

  final ResidencyBudgetLoader _loadBudgetBytes;
  final ModelResidencyPolicy _policy;
  final Map<String, ModelResidentSpec> _residents =
      <String, ModelResidentSpec>{};
  Future<void> _exclusiveTail = Future<void>.value();

  List<ModelResidentSpec> get residents => List.unmodifiable(_residents.values);

  bool isResident(String id) => _residents.containsKey(id);

  void markResident(ModelResidentSpec spec) {
    _residents[spec.id] = spec;
  }

  void removeResident(String id) {
    _residents.remove(id);
  }

  Future<ModelResidencyPlanResult> planFor(ModelResidentSpec incoming) async {
    final budgetBytes = await _loadBudgetBytes();
    return _policy.plan(
      currentResidents: residents,
      incoming: incoming,
      budgetBytes: budgetBytes,
    );
  }

  Future<bool> canLoadWithoutEviction(ModelResidentSpec incoming) async {
    final plan = await planFor(incoming);
    return plan.fits && plan.residentsToEvict.isEmpty;
  }

  Future<ModelResidencyPlanResult> makeRoomFor(
    ModelResidentSpec incoming, {
    ResidentEvictionCallback? onEvict,
  }) async {
    return runExclusive<ModelResidencyPlanResult>(
      'makeRoomFor:${incoming.id}',
      () async {
        final plan = await planFor(incoming);
        if (!plan.fits) {
          return plan;
        }

        for (final resident in plan.residentsToEvict) {
          if (onEvict != null) {
            await onEvict(resident);
          }
          removeResident(resident.id);
        }

        return plan;
      },
    );
  }

  Future<EnsureResidentResult> ensureResident(
    ModelResidentSpec incoming, {
    required ResidentLoadCallback onLoad,
    ResidentEvictionCallback? onEvict,
    bool allowEviction = true,
  }) {
    return runExclusive<EnsureResidentResult>(
      'ensureResident:${incoming.id}',
      () async {
        if (isResident(incoming.id)) {
          return EnsureResidentResult(
            status: EnsureResidentStatus.alreadyResident,
            spec: incoming,
          );
        }

        ModelResidencyPlanResult? plan;
        if (!await canLoadWithoutEviction(incoming)) {
          if (!allowEviction) {
            plan = await planFor(incoming);
            return EnsureResidentResult(
              status: EnsureResidentStatus.blocked,
              spec: incoming,
              plan: plan,
            );
          }

          plan = await makeRoomFor(incoming, onEvict: onEvict);
          if (!plan.fits) {
            return EnsureResidentResult(
              status: EnsureResidentStatus.blocked,
              spec: incoming,
              plan: plan,
            );
          }
        }

        final loaded = await onLoad();
        if (!loaded) {
          return EnsureResidentResult(
            status: EnsureResidentStatus.failed,
            spec: incoming,
            plan: plan,
          );
        }

        markResident(incoming);
        return EnsureResidentResult(
          status: EnsureResidentStatus.loaded,
          spec: incoming,
          plan: plan,
        );
      },
    );
  }

  Future<T> runExclusive<T>(String label, Future<T> Function() action) {
    final operation = _exclusiveTail.then((_) => action());
    _exclusiveTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  static Future<int> _defaultBudgetBytes() async {
    final manager = MemoryBudgetManager();
    final memoryInfo = await manager.getCurrentMemoryInfo(forceRefresh: true);
    return manager.calculateBudget(memoryInfo);
  }
}
