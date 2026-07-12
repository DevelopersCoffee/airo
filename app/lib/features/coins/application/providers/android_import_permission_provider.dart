import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/android_finance_import_preferences.dart';
import '../services/android_finance_import_service.dart';
import '../services/finance_chat_ingestion_service.dart';
import '../../domain/services/finance_message_parser.dart';
import 'expense_providers.dart';

final androidFinanceImportPreferencesProvider =
    Provider<AndroidFinanceImportPreferences>(
      (ref) => const AndroidFinanceImportPreferences(),
    );

final androidFinanceImportPermissionControllerProvider =
    StateNotifierProvider<
      AndroidFinanceImportPermissionController,
      AsyncValue<AndroidFinanceImportPermission>
    >((ref) {
      final preferences = ref.watch(androidFinanceImportPreferencesProvider);
      return AndroidFinanceImportPermissionController(preferences);
    });

final androidFinanceImportServiceProvider =
    Provider<AndroidFinanceImportService>((ref) {
      final preferences = ref.watch(androidFinanceImportPreferencesProvider);
      final repository = ref.watch(transactionRepositoryProvider);
      return AndroidFinanceImportService(
        ingestionService: FinanceChatIngestionService(
          parser: const FinanceMessageParser(),
          repository: repository,
        ),
        permissionReader: preferences.readPermission,
      );
    });

class AndroidFinanceImportPermissionController
    extends StateNotifier<AsyncValue<AndroidFinanceImportPermission>> {
  AndroidFinanceImportPermissionController(this._preferences)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final AndroidFinanceImportPreferences _preferences;

  Future<void> _load() async {
    try {
      state = AsyncValue.data(await _preferences.readPermission());
    } catch (_) {
      state = const AsyncValue.data(AndroidFinanceImportPermission.disabled);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = const AsyncValue.loading();
    try {
      await _preferences.setEnabled(enabled);
      state = AsyncValue.data(
        enabled
            ? AndroidFinanceImportPermission.enabled
            : AndroidFinanceImportPermission.disabled,
      );
    } catch (_) {
      state = const AsyncValue.data(AndroidFinanceImportPermission.disabled);
    }
  }
}
