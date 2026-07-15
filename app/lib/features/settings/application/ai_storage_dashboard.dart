import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_storage_dashboard_service_stub.dart'
    if (dart.library.io) 'ai_storage_dashboard_service_io.dart'
    as platform;

enum AIStorageCategoryKind {
  installedModels,
  meetingStorage,
  embeddingStorage,
  databaseSize,
  audioCache,
  availableSpace,
}

class AIStorageDashboardCategory {
  const AIStorageDashboardCategory({
    required this.kind,
    required this.label,
    required this.bytes,
    this.available = true,
  });

  final AIStorageCategoryKind kind;
  final String label;
  final int bytes;
  final bool available;

  @override
  String toString() {
    return 'AIStorageDashboardCategory(kind: $kind, label: $label, bytes: $bytes, available: $available)';
  }
}

class AIStorageDashboardSummary {
  const AIStorageDashboardSummary({required this.categories});

  final List<AIStorageDashboardCategory> categories;

  int get totalUsedBytes => categories
      .where(
        (category) => category.kind != AIStorageCategoryKind.availableSpace,
      )
      .fold<int>(0, (total, category) => total + category.bytes);

  AIStorageDashboardCategory category(AIStorageCategoryKind kind) {
    return categories.firstWhere((category) => category.kind == kind);
  }

  @override
  String toString() {
    return 'AIStorageDashboardSummary(categories: $categories, totalUsedBytes: $totalUsedBytes)';
  }
}

final aiStorageDashboardProvider = FutureProvider<AIStorageDashboardSummary>((
  ref,
) async {
  return AIStorageDashboardService().loadSummary();
});

class AIStorageDashboardService {
  const AIStorageDashboardService();

  Future<AIStorageDashboardSummary> loadSummary() =>
      platform.loadAIStorageDashboardSummary();
}
