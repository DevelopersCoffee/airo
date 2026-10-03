import '../application/use_cases/add_expense_use_case.dart';
import '../entities/transaction.dart';
import '../result.dart';
import '../currency/coins_amount_input.dart';
import 'nfc_quick_expense_capture_draft.dart';
import 'nfc_quick_expense_categories.dart';

/// Maps the quick-capture draft to [AddExpenseParams] and coordinates save vs
/// cancel (cancel never touches the repository).
class NfcQuickExpenseCaptureService {
  const NfcQuickExpenseCaptureService();

  /// Parses a user-entered amount string (e.g. `300`, `300.50`) into cents.
  ///
  /// Returns null when the value is missing, non-numeric, or non-positive.
  int? parseAmountCents(String raw) => CoinsAmountInput.parseToCents(raw);

  /// Builds repository params when the user confirms; null when the draft is
  /// incomplete or [userConfirmed] is false (cancel / dismiss).
  AddExpenseParams? buildSaveParams({
    required NfcQuickExpenseCaptureDraft draft,
    required String accountId,
    required bool userConfirmed,
  }) {
    if (!userConfirmed || !draft.isReadyToSave) {
      return null;
    }
    final category = NfcQuickExpenseCategories.byId(draft.categoryId!);
    if (category == null) {
      return null;
    }

    final trimmedNote = draft.note?.trim();
    final description = (trimmedNote != null && trimmedNote.isNotEmpty)
        ? trimmedNote
        : category.label;

    return AddExpenseParams(
      description: description,
      amountCents: draft.amountCents!,
      type: TransactionType.expense,
      categoryId: category.id,
      accountId: accountId,
      notes: trimmedNote != null && trimmedNote.isNotEmpty ? trimmedNote : null,
      tags: const ['nfc_quick_capture'],
    );
  }

  Future<Result<Transaction>?> save({
    required AddExpenseUseCase addExpense,
    required NfcQuickExpenseCaptureDraft draft,
    required String accountId,
    required bool userConfirmed,
  }) async {
    final params = buildSaveParams(
      draft: draft,
      accountId: accountId,
      userConfirmed: userConfirmed,
    );
    if (params == null) {
      return null;
    }
    return addExpense.execute(params);
  }
}
