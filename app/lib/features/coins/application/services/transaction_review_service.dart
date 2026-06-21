import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

const transactionReviewPendingTag = 'review:pending';
const transactionReviewApprovedTag = 'review:approved';
const transactionReviewRejectedTag = 'review:rejected';
const transactionReviewDuplicateTag = 'review:duplicate';

class TransactionReviewEdit {
  final int? amountCents;
  final DateTime? transactionDate;
  final String? merchant;
  final String? categoryId;
  final String? accountId;

  const TransactionReviewEdit({
    this.amountCents,
    this.transactionDate,
    this.merchant,
    this.categoryId,
    this.accountId,
  });
}

class TransactionReviewService {
  final TransactionRepository _repository;

  const TransactionReviewService({required TransactionRepository repository})
    : _repository = repository;

  Future<Result<List<Transaction>>> pendingImportedTransactions() async {
    return _repository.findByTag(transactionReviewPendingTag);
  }

  Future<Result<Transaction>> approve(String id) async {
    final currentResult = await _repository.findById(id);
    final current = currentResult.data;
    if (currentResult.error != null || current == null) {
      return (
        data: null,
        error: currentResult.error ?? 'Transaction not found',
      );
    }

    return _repository.update(
      current.copyWith(
        tags: _withReviewState(current.tags, transactionReviewApprovedTag),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<Result<Transaction>> edit(
    String id,
    TransactionReviewEdit edit,
  ) async {
    final currentResult = await _repository.findById(id);
    final current = currentResult.data;
    if (currentResult.error != null || current == null) {
      return (
        data: null,
        error: currentResult.error ?? 'Transaction not found',
      );
    }

    final amountCents = edit.amountCents ?? current.amountCents;
    final updated = current.copyWith(
      description: _nonEmptyOr(edit.merchant, current.description),
      amountCents: amountCents,
      type: amountCents >= 0 ? TransactionType.income : TransactionType.expense,
      categoryId: _nonEmptyOr(edit.categoryId, current.categoryId),
      accountId: _nonEmptyOr(edit.accountId, current.accountId),
      transactionDate: edit.transactionDate ?? current.transactionDate,
      updatedAt: DateTime.now(),
    );

    return _repository.update(updated);
  }

  Future<Result<Transaction>> reject(String id) async {
    return _closeAs(id, transactionReviewRejectedTag);
  }

  Future<Result<Transaction>> markDuplicate(String id) async {
    return _closeAs(id, transactionReviewDuplicateTag);
  }

  Future<Result<Transaction>> _closeAs(String id, String reviewStateTag) async {
    final currentResult = await _repository.findById(id);
    final current = currentResult.data;
    if (currentResult.error != null || current == null) {
      return (
        data: null,
        error: currentResult.error ?? 'Transaction not found',
      );
    }

    final updated = current.copyWith(
      tags: _withReviewState(current.tags, reviewStateTag),
      updatedAt: DateTime.now(),
    );
    final updateResult = await _repository.update(updated);
    if (updateResult.error != null) return updateResult;

    final deleteResult = await _repository.delete(id);
    if (deleteResult.error != null) {
      return (data: null, error: deleteResult.error);
    }

    final deletedResult = await _repository.findById(id);
    return deletedResult.data == null ? updateResult : deletedResult;
  }

  List<String> _withReviewState(List<String> tags, String reviewStateTag) {
    return <String>{
      ...tags.where((tag) => !tag.startsWith('review:')),
      reviewStateTag,
    }.toList(growable: false);
  }

  String _nonEmptyOr(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }
}
