import 'package:feature_coins_core/src/application/use_cases/add_expense_use_case.dart';
import 'package:feature_coins_core/src/entities/transaction.dart';
import 'package:feature_coins_core/src/nfc_quick_capture/nfc_quick_expense_capture_draft.dart';
import 'package:feature_coins_core/src/nfc_quick_capture/nfc_quick_expense_capture_service.dart';
import 'package:feature_coins_core/src/repositories/transaction_repository.dart';
import 'package:feature_coins_core/src/result.dart';
import 'package:test/test.dart';

class _RecordingRepository implements TransactionRepository {
  Transaction? lastCreated;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Result<Transaction>> create(Transaction transaction) async {
    lastCreated = transaction;
    return (data: transaction, error: null);
  }
}

void main() {
  const service = NfcQuickExpenseCaptureService();

  group('parseAmountCents', () {
    test('parses amounts with optional currency symbols stripped', () {
      expect(service.parseAmountCents('300'), 30000);
      expect(service.parseAmountCents('₹300'), 30000);
      expect(service.parseAmountCents('\$42.50'), 4250);
      expect(service.parseAmountCents('€10,99'), 1099);
    });

    test('rejects invalid amounts', () {
      expect(service.parseAmountCents(''), isNull);
      expect(service.parseAmountCents('abc'), isNull);
      expect(service.parseAmountCents('0'), isNull);
    });
  });

  group('buildSaveParams', () {
    const draft = NfcQuickExpenseCaptureDraft(
      amountCents: 30000,
      categoryId: 'food',
      note: '  ',
    );

    test('cancel returns null', () {
      expect(
        service.buildSaveParams(
          draft: draft,
          accountId: 'cash_default',
          userConfirmed: false,
        ),
        isNull,
      );
    });

    test('confirm builds expense params with category as description', () {
      final params = service.buildSaveParams(
        draft: draft,
        accountId: 'cash_default',
        userConfirmed: true,
      );
      expect(params, isNotNull);
      expect(params!.amountCents, 30000);
      expect(params.categoryId, 'food');
      expect(params.description, 'Food');
      expect(params.notes, isNull);
      expect(params.tags, contains('nfc_quick_capture'));
    });

    test('note becomes description and notes when non-empty', () {
      final params = service.buildSaveParams(
        draft: const NfcQuickExpenseCaptureDraft(
          amountCents: 5000,
          categoryId: 'transport',
          note: 'Metro',
        ),
        accountId: 'cash_default',
        userConfirmed: true,
      );
      expect(params!.description, 'Metro');
      expect(params.notes, 'Metro');
    });
  });

  group('save', () {
    test('persists through AddExpenseUseCase when confirmed', () async {
      final repo = _RecordingRepository();
      final addExpense = AddExpenseUseCase(repo);
      const draft = NfcQuickExpenseCaptureDraft(
        amountCents: 30000,
        categoryId: 'food',
      );

      final result = await service.save(
        addExpense: addExpense,
        draft: draft,
        accountId: 'cash_default',
        userConfirmed: true,
      );

      expect(result?.error, isNull);
      expect(repo.lastCreated?.amountCents, -30000);
      expect(repo.lastCreated?.categoryId, 'food');
    });

    test('does not persist on cancel', () async {
      final repo = _RecordingRepository();
      final addExpense = AddExpenseUseCase(repo);
      const draft = NfcQuickExpenseCaptureDraft(
        amountCents: 30000,
        categoryId: 'food',
      );

      final result = await service.save(
        addExpense: addExpense,
        draft: draft,
        accountId: 'cash_default',
        userConfirmed: false,
      );

      expect(result, isNull);
      expect(repo.lastCreated, isNull);
    });
  });
}
