import 'package:flutter_test/flutter_test.dart';

import '../../../../fixtures/ocr/sample_receipts.dart';
import 'fake_ocr_client.dart';
import 'receipt_parser_service_test.dart';

/// OCR module tests using deterministic fake OCR client
void main() {
  group('FakeOcrClient', () {
    late FakeOcrClient ocrClient;

    setUp(() {
      ocrClient = FakeOcrClient();
    });

    tearDown(() {
      ocrClient.dispose();
    });

    test('returns default result for unknown images', () async {
      final result = await ocrClient.processImage('/path/to/unknown.jpg');

      expect(result.text, equals('No text detected'));
      expect(result.confidence, equals(0.0));
      expect(ocrClient.wasCalled('processImage'), isTrue);
    });

    test('returns configured fixture for known images', () async {
      ocrClient.addFixture(
        '/path/to/receipt.jpg',
        const OcrResult(text: 'Test receipt', confidence: 0.95),
      );

      final result = await ocrClient.processImage('/path/to/receipt.jpg');

      expect(result.text, equals('Test receipt'));
      expect(result.confidence, equals(0.95));
    });

    test('logs all method calls for verification', () async {
      await ocrClient.processImage('/path/1.jpg');
      await ocrClient.processImage('/path/2.jpg');
      await ocrClient.processImageBytes([1, 2, 3]);
      ocrClient.dispose();

      expect(ocrClient.callCount('processImage'), equals(2));
      expect(ocrClient.callCount('processImageBytes'), equals(1));
      expect(ocrClient.wasCalled('dispose'), isTrue);
    });

    test('reset clears call log', () async {
      await ocrClient.processImage('/path/test.jpg');
      expect(ocrClient.callLog.isNotEmpty, isTrue);

      ocrClient.reset();
      expect(ocrClient.callLog.isEmpty, isTrue);
    });
  });

  group('OCR Text Parsing - Instamart', () {
    test('extracts vendor from Instamart receipt', () {
      final vendor = extractVendor(instamartReceiptOcr);
      expect(vendor, equals('Instamart'));
    });

    test('parses 7 items from Instamart receipt', () {
      final items = parseInstamartItems(instamartReceiptOcr);

      expect(items.length, equals(7));
      expect(items[0]['name'], contains('Potato'));
      expect(items[0]['price'], equals(41.0));
      expect(items[6]['name'], contains('Milk'));
      expect(items[6]['price'], equals(58.0));
    });

    test('extracts grand total of 288', () {
      final total = extractGrandTotal(instamartReceiptOcr);
      expect(total, equals(28800)); // in paise
    });
  });

  group('OCR Text Parsing - Multiple Vendors', () {
    test('detects Zepto vendor', () {
      final vendor = extractVendor(zeptoReceiptOcr);
      expect(vendor, equals('Zepto'));
    });

    test('detects BigBasket vendor', () {
      final vendor = extractVendor(bigbasketReceiptOcr);
      expect(vendor, equals('BigBasket'));
    });

    test('detects Blinkit vendor', () {
      final vendor = extractVendor(blinkitReceiptOcr);
      expect(vendor, equals('Blinkit'));
    });

    test('returns null for unknown vendor', () {
      const ocrText = 'Random Store Receipt\nItem: Apple\nPrice: 50.00';
      final vendor = extractVendor(ocrText);
      expect(vendor, isNull);
    });
  });

  group('OCR Price Correction', () {
    test('handles corrupted rupee symbols (F, Z, T)', () {
      expect(parseCorruptedPrice('F41.0'), equals(4100));
      expect(parseCorruptedPrice('Z69,0'), equals(6900));
      expect(parseCorruptedPrice('T20.0'), equals(2000));
      expect(parseCorruptedPrice('29.0'), equals(2900));
      expect(parseCorruptedPrice('R95.00'), equals(9500));
    });

    test('keeps valid prices in 700s range (not strip leading 7)', () {
      // Prices like ₹741 are VALID and should NOT be "corrected" to ₹41
      // OCR ₹→7 corruption should be handled at parse time via corrupted char detection
      final rawPrices = [74100, 73800, 76900, 4500, 12000];
      final corrected = correctPrices(rawPrices, null, 5);

      // All prices up to ₹1000 are kept as-is
      expect(corrected[0], equals(74100)); // ₹741 stays
      expect(corrected[1], equals(73800)); // ₹738 stays
      expect(corrected[2], equals(76900)); // ₹769 stays
      expect(corrected[3], equals(4500)); // ₹45 stays
      expect(corrected[4], equals(12000)); // ₹120 stays
    });

    test('skips prices that are way too high', () {
      // Filter out unreasonably high prices (over ₹1000 for groceries)
      final rawPrices = [150000, 4500]; // ₹1500 (too high), ₹45
      final corrected = correctPrices(rawPrices, null, 2);

      expect(corrected.length, equals(1));
      expect(corrected[0], equals(4500));
    });
  });

  group('OCR Edge Cases', () {
    test('handles empty OCR text', () {
      final items = parseInstamartItems('');
      expect(items, isEmpty);
    });

    test('handles OCR text with no items', () {
      const ocrText = 'Some random text\nNo item patterns here';
      final items = parseInstamartItems(ocrText);
      expect(items, isEmpty);
    });

    test('handles whitespace-only OCR text', () {
      const ocrText = '   \n\t\n   ';
      final items = parseInstamartItems(ocrText);
      expect(items, isEmpty);
    });
  });
}
