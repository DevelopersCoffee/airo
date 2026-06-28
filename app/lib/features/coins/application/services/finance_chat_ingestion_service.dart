import 'dart:convert';

import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/services/finance_message_parser.dart';
import 'transaction_review_service.dart';

enum FinanceChatIngestionStatus {
  ignored,
  created,
  updated,
  needsReview,
  failed,
}

class FinanceChatIngestionResult {
  final FinanceChatIngestionStatus status;
  final ParsedFinanceMessage? parsed;
  final Transaction? transaction;
  final String? message;

  const FinanceChatIngestionResult({
    required this.status,
    this.parsed,
    this.transaction,
    this.message,
  });

  bool get changedLedger =>
      status == FinanceChatIngestionStatus.created ||
      status == FinanceChatIngestionStatus.updated ||
      (status == FinanceChatIngestionStatus.needsReview && transaction != null);
}

/// Turns pasted finance SMS/notifications into local Coins transactions.
class FinanceChatIngestionService {
  final FinanceMessageParser _parser;
  final TransactionRepository _repository;

  const FinanceChatIngestionService({
    required FinanceMessageParser parser,
    required TransactionRepository repository,
  }) : _parser = parser,
       _repository = repository;

  Future<FinanceChatIngestionResult> ingest(
    String text, {
    required String accountId,
  }) async {
    final parsed = _parser.parse(text);
    if (parsed == null) {
      return const FinanceChatIngestionResult(
        status: FinanceChatIngestionStatus.ignored,
      );
    }

    final existingResult = await _repository.findByTag(parsed.sourceTag);
    if (existingResult.error != null) {
      return FinanceChatIngestionResult(
        status: FinanceChatIngestionStatus.failed,
        parsed: parsed,
        message: existingResult.error,
      );
    }

    final existing = existingResult.data ?? const <Transaction>[];
    if (existing.isNotEmpty) {
      final current = existing.first;
      final updated = current.copyWith(
        description: parsed.description,
        amountCents: _signedAmount(parsed),
        type: parsed.type,
        categoryId: parsed.categoryId,
        accountId: accountId,
        transactionDate: parsed.transactionDate,
        tags: _mergeTags(current.tags, parsed, text),
        updatedAt: DateTime.now(),
      );
      final updateResult = await _repository.update(updated);
      if (updateResult.error != null) {
        return FinanceChatIngestionResult(
          status: FinanceChatIngestionStatus.failed,
          parsed: parsed,
          message: updateResult.error,
        );
      }
      return FinanceChatIngestionResult(
        status: FinanceChatIngestionStatus.needsReview,
        parsed: parsed,
        transaction: updateResult.data,
        message: parsed.isHighConfidence
            ? 'Queued imported transaction for review.'
            : 'Queued possible transaction for review.',
      );
    }

    final now = DateTime.now();
    final transaction = Transaction(
      id: 'chat_txn_${parsed.sourceHash}',
      description: parsed.description,
      amountCents: _signedAmount(parsed),
      type: parsed.type,
      categoryId: parsed.categoryId,
      accountId: accountId,
      transactionDate: parsed.transactionDate,
      tags: _mergeTags(const [], parsed, text),
      createdAt: now,
    );
    final createResult = await _repository.create(transaction);
    if (createResult.error != null) {
      return FinanceChatIngestionResult(
        status: FinanceChatIngestionStatus.failed,
        parsed: parsed,
        message: createResult.error,
      );
    }
    return FinanceChatIngestionResult(
      status: FinanceChatIngestionStatus.needsReview,
      parsed: parsed,
      transaction: createResult.data,
      message: parsed.isHighConfidence
          ? 'Queued imported transaction for review.'
          : 'Queued possible transaction for review.',
    );
  }

  int _signedAmount(ParsedFinanceMessage parsed) {
    return parsed.type == TransactionType.expense
        ? -parsed.amountCents.abs()
        : parsed.amountCents.abs();
  }

  List<String> _mergeTags(
    List<String> currentTags,
    ParsedFinanceMessage parsed,
    String rawText,
  ) {
    return <String>{
      ...currentTags,
      'source:chat',
      'source:finance_sms',
      'source:parser:finance_message_parser',
      'parser_version:v1',
      parsed.sourceTag,
      'confidence:${parsed.confidence.toStringAsFixed(2)}',
      transactionReviewPendingTag,
      'source:raw_text_b64:${base64Url.encode(utf8.encode(rawText))}',
    }.toList(growable: false);
  }
}
