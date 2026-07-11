import 'finance_chat_ingestion_service.dart';

enum AndroidFinanceImportPermission { disabled, enabled }

enum AndroidFinanceImportStatus {
  permissionDisabled,
  ignored,
  queuedForReview,
  failed,
}

class AndroidFinanceImportResult {
  final AndroidFinanceImportStatus status;
  final FinanceChatIngestionResult? ingestionResult;
  final String message;

  const AndroidFinanceImportResult({
    required this.status,
    required this.message,
    this.ingestionResult,
  });
}

class AndroidFinanceImportService {
  final FinanceChatIngestionService ingestionService;
  final Future<AndroidFinanceImportPermission> Function() permissionReader;

  const AndroidFinanceImportService({
    required this.ingestionService,
    required this.permissionReader,
  });

  Future<AndroidFinanceImportResult> importText(
    String rawText, {
    required String accountId,
  }) async {
    final permission = await permissionReader();
    if (permission != AndroidFinanceImportPermission.enabled) {
      return const AndroidFinanceImportResult(
        status: AndroidFinanceImportStatus.permissionDisabled,
        message:
            'Enable Android SMS or notification import before Airo reads bank, UPI, or card alerts.',
      );
    }

    final ingestion = await ingestionService.ingest(
      rawText,
      accountId: accountId,
      sourceTags: const ['source:android_import'],
    );

    return switch (ingestion.status) {
      FinanceChatIngestionStatus.ignored => AndroidFinanceImportResult(
        status: AndroidFinanceImportStatus.ignored,
        ingestionResult: ingestion,
        message: 'Ignored non-financial or sensitive authentication message.',
      ),
      FinanceChatIngestionStatus.failed => AndroidFinanceImportResult(
        status: AndroidFinanceImportStatus.failed,
        ingestionResult: ingestion,
        message: ingestion.message ?? 'Android finance import failed.',
      ),
      _ => AndroidFinanceImportResult(
        status: AndroidFinanceImportStatus.queuedForReview,
        ingestionResult: ingestion,
        message: ingestion.message ?? 'Queued imported transaction for review.',
      ),
    };
  }
}
