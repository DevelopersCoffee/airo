import 'package:core_ai/core_ai.dart' show SafetyProfile;
import 'package:core_app_shell/core_app_shell.dart'
    show currencyFormatterProvider;
import 'package:feature_assistant/feature_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/coins/application/providers/dashboard_providers.dart';
import '../../features/coins/application/providers/expense_providers.dart';
import '../../features/coins/application/services/finance_chat_ingestion_service.dart';
import '../../features/settings/presentation/widgets/ai_preferences_section.dart';
import '../../features/settings/application/ai_preferences_settings.dart';
import '../../features/settings/presentation/intelligent_model_manager_provider.dart';
import '../../shared/widgets/bug_report_dialog.dart';
import '../accessibility/airo_speech_service.dart';
import '../auth/auth_service.dart';
import '../auth/google_auth_service.dart';
import '../dictionary/dictionary.dart';
import '../http/http_dog.dart';
import '../platform/platform_config.dart';
import '../routing/route_names.dart';

/// The super app's implementation of the assistant package's host seam.
///
/// Every member here is a thin wrapper over an app-owned service; the
/// assistant package sees only [AssistantHostAdapter]. The shell installs it
/// by overriding `assistantHostAdapterProvider` — see
/// `core/app/main_provider_overrides.dart`.
class AppAssistantHostAdapter extends AssistantHostAdapter {
  const AppAssistantHostAdapter(this._ref);

  final Ref _ref;

  @override
  AssistantHostUser? get currentUser {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;
    return AssistantHostUser(
      id: user.id,
      username: user.username,
      isGoogleUser: user.isGoogleUser,
    );
  }

  @override
  Future<void> signOutAndReturnToLogin(BuildContext context) async {
    final user = AuthService.instance.currentUser;
    if (user?.isGoogleUser == true) {
      await GoogleAuthService.instance.signOut();
    }
    await AuthService.instance.logout();
    if (context.mounted) {
      context.go(RouteNames.login);
    }
  }

  @override
  void openHostSettings(BuildContext context) =>
      context.push(RouteNames.settings);

  @override
  void openHttpStatusReference(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const HttpStatusReferenceScreen(),
      ),
    );
  }

  @override
  void openDictionaryDemo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const DictionaryDemoScreen(),
      ),
    );
  }

  @override
  Future<bool> speakAloud(String text) =>
      AiroSpeechService.instance.speak(text);

  @override
  Widget wrapWithDictionarySelection({required Widget child}) =>
      DictionarySelectionArea(child: child);

  @override
  void showWordDefinition(BuildContext context, String word) =>
      DictionaryPopup.showAdaptive(context, word);

  @override
  Widget dictionaryAwareText(String text) => SelectableTextWithDictionary(text);

  @override
  Future<void> showBugReportDialog(BuildContext context) =>
      BugReportDialog.show(context);

  @override
  Widget aiPreferencesSection() => const AIPreferencesSection();

  @override
  SafetyProfile get safetyProfile =>
      _ref.read(aiPreferencesSettingsProvider).safetyProfile;

  @override
  bool get autoFallbackEnabled =>
      _ref.read(aiPreferencesSettingsProvider).autoFallback;

  @override
  int get modelContextLength =>
      _ref.read(aiPreferencesSettingsProvider).contextLength;

  @override
  Future<void> setModelContextLength(int tokens) {
    final notifier = _ref.read(aiPreferencesSettingsProvider.notifier);
    return notifier.update(
      _ref.read(aiPreferencesSettingsProvider).copyWith(contextLength: tokens),
    );
  }

  @override
  Future<void> repairModelPackage(String packageId) =>
      _ref.read(intelligentModelManagerProvider).repairModel(packageId);

  @override
  bool get isAndroidHost => PlatformConfig.isAndroid;

  @override
  Future<AssistantFinanceIngestion?> ingestFinanceMessage(
    String message,
  ) async {
    final accounts = await _ref.read(expenseAccountOptionsProvider.future);
    if (accounts.isEmpty) return null;
    final defaultAccount = accounts
        .where((account) => account.isDefault)
        .fold(accounts.first, (selected, account) => account);

    final result = await _ref
        .read(financeChatIngestionServiceProvider)
        .ingest(message, accountId: defaultAccount.id);

    if (result.status == FinanceChatIngestionStatus.ignored) return null;

    if (result.changedLedger) {
      _refreshCoinsProviders();
    }

    final undoLabel = _undoLabel(result);
    return AssistantFinanceIngestion(
      responseText: _ingestionResponse(result),
      undoLabel: undoLabel,
      onUndo: undoLabel == null ? null : () => _undo(result),
    );
  }

  String? _undoLabel(FinanceChatIngestionResult result) {
    final transaction = result.transaction;
    if (transaction == null) return null;
    if (result.status != FinanceChatIngestionStatus.created &&
        result.status != FinanceChatIngestionStatus.needsReview) {
      return null;
    }
    return 'Added ${transaction.description} to Coins.';
  }

  Future<String?> _undo(FinanceChatIngestionResult result) async {
    final transaction = result.transaction!;
    final deleteResult = await _ref
        .read(transactionRepositoryProvider)
        .delete(transaction.id);
    if (deleteResult.error != null) return null;
    _refreshCoinsProviders();
    return 'Removed ${transaction.description} from Coins.';
  }

  void _refreshCoinsProviders() {
    _ref.invalidate(allExpensesProvider);
    _ref.invalidate(recentExpensesProvider);
    _ref.invalidate(spentTodayProvider);
    _ref.invalidate(spentThisMonthProvider);
    _ref.invalidate(monthlySpendingByCategoryProvider);
    _ref.invalidate(dashboardDataProvider);
  }

  String _ingestionResponse(FinanceChatIngestionResult result) {
    final formatter = _ref.read(currencyFormatterProvider);
    final parsed = result.parsed;
    if (parsed == null) {
      return 'I could not read this as a finance transaction.';
    }

    final amount = formatter.formatCents(parsed.amountCents);
    switch (result.status) {
      case FinanceChatIngestionStatus.created:
        return 'Added to Coins: ${parsed.description} - $amount - ${parsed.categoryId}.';
      case FinanceChatIngestionStatus.updated:
        return 'Updated Coins: ${parsed.description} - $amount - ${parsed.categoryId}.';
      case FinanceChatIngestionStatus.needsReview:
        if (result.transaction != null) {
          return 'Queued for Coins review: ${parsed.description} - $amount - ${parsed.categoryId}.';
        }
        return 'I found a possible transaction for ${parsed.description} - $amount, but it needs review before I add it.';
      case FinanceChatIngestionStatus.failed:
        return result.message ?? 'I could not update Coins from this message.';
      case FinanceChatIngestionStatus.ignored:
        return 'I could not read this as a finance transaction.';
    }
  }
}
