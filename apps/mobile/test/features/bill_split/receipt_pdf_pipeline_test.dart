import 'dart:io';
import 'dart:typed_data';

import 'package:airo_app/features/bill_split/domain/services/receipt_parser_service.dart';
import 'package:airo_app/features/bill_split/domain/services/receipt_pdf_renderer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'merges rendered PDF page OCR text in page order deterministically',
    () async {
      final parser = MLKitReceiptParserService(
        pdfRenderer: _FakePdfRenderer([_page(2), _page(1)]),
        pdfPageTextExtractor: _FakePageTextExtractor({
          1: _invoicePageOneText,
          2: _invoicePageTwoText,
        }),
      );

      final first = await parser.parseReceiptPdf(File('urban-company.pdf'));
      final second = await parser.parseReceiptPdf(File('urban-company.pdf'));

      expect(first.vendor, 'Urban Company');
      expect(first.orderId, '260010284981');
      expect(first.items.single.name, 'Convenience and Platform Fee - Plumber');
      expect(first.items.single.totalPricePaise, 900);
      expect(first.grandTotalPaise, 900);

      expect(second.vendor, first.vendor);
      expect(second.orderId, first.orderId);
      expect(
        second.items.map((item) => item.name),
        first.items.map((item) => item.name),
      );
      expect(
        second.items.map((item) => item.totalPricePaise),
        first.items.map((item) => item.totalPricePaise),
      );
      expect(second.grandTotalPaise, first.grandTotalPaise);
    },
  );

  test('routes PDF bytes through the renderer without fallback', () async {
    final renderer = _FakePdfRenderer([_page(1)]);
    final parser = MLKitReceiptParserService(
      pdfRenderer: renderer,
      pdfPageTextExtractor: _FakePageTextExtractor({
        1: 'Items\nConvenience and Platform Fee - Plumber\nTOTAL AMOUNT\nRs. 9',
      }),
    );

    final receipt = await parser.parseReceiptFromBytes([
      1,
      2,
      3,
    ], mimeType: 'application/pdf');

    expect(renderer.renderBytesCalls, 1);
    expect(receipt.grandTotalPaise, 900);
  });

  test('merges independent invoice pages without cross-page total bleed', () {
    final parser = MLKitReceiptParserService();

    final receipt = parser.parseRecognizedPageTextsForTesting([
      _invoicePageOneText + _invoicePageTwoText,
      'Download invoice\nScan this QR code',
      _serviceInvoiceText,
    ]);

    expect(receipt.items.map((item) => item.name), [
      'Convenience and Platform Fee - Plumber',
      'Minor Plumbing Repair',
    ]);
    expect(receipt.items.map((item) => item.totalPricePaise), [900, 43700]);
    expect(receipt.grandTotalPaise, 44600);
  });
}

RenderedPdfPage _page(int pageNumber) {
  return RenderedPdfPage(
    pageNumber: pageNumber,
    bytes: Uint8List.fromList([pageNumber]),
  );
}

class _FakePdfRenderer implements ReceiptPdfRenderer {
  _FakePdfRenderer(this.pages);

  final List<RenderedPdfPage> pages;
  int renderBytesCalls = 0;

  @override
  Future<List<RenderedPdfPage>> renderFile(File pdfFile) async => pages;

  @override
  Future<List<RenderedPdfPage>> renderBytes(List<int> bytes) async {
    renderBytesCalls++;
    return pages;
  }
}

class _FakePageTextExtractor implements RenderedReceiptPageTextExtractor {
  _FakePageTextExtractor(this.textByPage);

  final Map<int, String> textByPage;

  @override
  Future<String> extractText(RenderedPdfPage page) async {
    return textByPage[page.pageNumber] ?? '';
  }
}

const _invoicePageOneText = '''
Urban
Company
Invoice no.
UCIC260010284981
Items
Convenience and Platform Fee - Plumber
SAC: 999799
''';

const _invoicePageTwoText = '''
TAX INVOICE
Urban Company Limited
TOTAL AMOUNT
Taxable Value
Rs. 7.63
IGST @18%
Rs. 1.37
Rs. 9
''';

const _serviceInvoiceText = '''
Urban
Company
TAX INVOICE
Invoice no.
UCIC260010284982
Items
Minor Plumbing Repair
SAC: 998719
TOTAL AMOUNT
Taxable Value
Rs. 370.34
IGST @18%
Rs. 66.66
Rs. 437
''';
