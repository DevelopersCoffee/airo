import 'ai_storage_dashboard.dart';

Future<AIStorageDashboardSummary> loadAIStorageDashboardSummary() async {
  return const AIStorageDashboardSummary(
    categories: [
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.installedModels,
        label: 'Installed models',
        bytes: 0,
        available: false,
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.meetingStorage,
        label: 'Meeting storage',
        bytes: 0,
        available: false,
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.embeddingStorage,
        label: 'Embedding storage',
        bytes: 0,
        available: false,
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.databaseSize,
        label: 'Database size',
        bytes: 0,
        available: false,
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.audioCache,
        label: 'Audio cache',
        bytes: 0,
        available: false,
      ),
      AIStorageDashboardCategory(
        kind: AIStorageCategoryKind.availableSpace,
        label: 'Available space',
        bytes: 0,
        available: false,
      ),
    ],
  );
}
