import 'dart:io';

import 'package:airo_app/features/bill_split/domain/models/receipt_item.dart';
import 'package:airo_app/features/bill_split/domain/services/receipt_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('byte parsing keeps fallback disabled by default', () async {
    final fallback = _FakeReceiptParsingFallback();
    final parser = MLKitReceiptParserService(fallback: fallback);

    await expectLater(
      parser.parseReceiptFromBytes([1, 2, 3], mimeType: 'image/png'),
      throwsA(isA<UnsupportedError>()),
    );

    expect(fallback.parseBytesCalls, 0);
  });

  test('byte parsing can use the explicit fallback hook later', () async {
    final fallback = _FakeReceiptParsingFallback(
      receipt: _receiptWithItem('Sourdough', 12000),
    );
    final parser = MLKitReceiptParserService(fallback: fallback);

    final receipt = await parser.parseReceiptFromBytes(
      [1, 2, 3],
      mimeType: 'image/png',
      allowFallback: true,
    );

    expect(receipt.items.single.name, 'Sourdough');
    expect(fallback.parseBytesCalls, 1);
    expect(fallback.lastMimeType, 'image/png');
  });
}

class _FakeReceiptParsingFallback implements ReceiptParsingFallback {
  _FakeReceiptParsingFallback({this.receipt});

  final ParsedReceipt? receipt;
  int parseBytesCalls = 0;
  String? lastMimeType;

  @override
  Future<ParsedReceipt?> parseImageFile(File imageFile) async => receipt;

  @override
  Future<ParsedReceipt?> parseBytes(
    List<int> bytes, {
    required String mimeType,
  }) async {
    parseBytesCalls++;
    lastMimeType = mimeType;
    return receipt;
  }
}

ParsedReceipt _receiptWithItem(String name, int pricePaise) {
  final item = ReceiptItem(
    id: 'item-1',
    name: name,
    quantity: 1,
    unitPricePaise: pricePaise,
    totalPricePaise: pricePaise,
  );

  return ParsedReceipt(
    id: 'receipt-1',
    vendor: 'Local Bakery',
    orderDate: DateTime(2026),
    items: [item],
    fees: const [],
    itemTotalPaise: pricePaise,
    grandTotalPaise: pricePaise,
    parsedAt: DateTime(2026),
  );
}
