import 'dart:io';

import 'package:airo_app/features/bill_split/domain/services/receipt_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parses image-only invoice PDF locally on device', (_) async {
    const pdfPath = String.fromEnvironment(
      'RECEIPT_PDF_PATH',
      defaultValue: '/data/local/tmp/uc_invoice.pdf',
    );
    final file = File(pdfPath);

    expect(
      file.existsSync(),
      isTrue,
      reason: 'Push the image-only receipt PDF to $pdfPath before running.',
    );

    final parser = MLKitReceiptParserService();
    final first = await parser.parseReceiptPdf(file);
    final second = await parser.parseReceiptPdf(file);

    expect(first.vendor, second.vendor);
    expect(first.grandTotalPaise, second.grandTotalPaise);
    expect(
      first.items.map((item) => item.name),
      second.items.map((item) => item.name),
    );
    expect(
      first.items.map((item) => item.totalPricePaise),
      second.items.map((item) => item.totalPricePaise),
    );

    expect(first.grandTotalPaise, 45500);
    expect(
      first.items.map((item) => item.name.toLowerCase()).join('\n'),
      contains('convenience'),
    );
  });
}
