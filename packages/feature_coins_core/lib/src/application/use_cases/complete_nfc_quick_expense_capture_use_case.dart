import '../../nfc_quick_capture/nfc_quick_expense_capture_draft.dart';
import '../../nfc_quick_capture/nfc_quick_expense_capture_service.dart';
import '../../entities/transaction.dart';
import '../../result.dart';
import 'add_expense_use_case.dart';

/// Saves a completed NFC quick-capture draft through [AddExpenseUseCase].
class CompleteNfcQuickExpenseCaptureUseCase {
  CompleteNfcQuickExpenseCaptureUseCase(
    this._addExpense, {
    NfcQuickExpenseCaptureService? captureService,
  }) : _captureService = captureService ?? const NfcQuickExpenseCaptureService();

  final AddExpenseUseCase _addExpense;
  final NfcQuickExpenseCaptureService _captureService;

  Future<Result<Transaction>?> execute({
    required NfcQuickExpenseCaptureDraft draft,
    required String accountId,
    required bool userConfirmed,
  }) {
    return _captureService.save(
      addExpense: _addExpense,
      draft: draft,
      accountId: accountId,
      userConfirmed: userConfirmed,
    );
  }
}
