import 'package:core_workers/core_workers.dart';
import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;

/// Syncfusion adapter. Extraction runs off the main isolate.
class SyncfusionAnyaPdfExtractor implements AnyaPdfTextExtractor {
  const SyncfusionAnyaPdfExtractor();

  @override
  Future<List<ExtractedPdfPage>> extractPages(List<int> pdfBytes) async {
    final rows = await runOffMain(() => extractSync(pdfBytes));
    return [
      for (final row in rows)
        ExtractedPdfPage(
          pageNumber: row['page']! as int,
          text: row['text']! as String,
        ),
    ];
  }

  /// Isolate entry — maps only so the result is isolate-sendable.
  static List<Map<String, Object>> extractSync(List<int> pdfBytes) {
    if (pdfBytes.isEmpty) return const [];
    final document = syncfusion.PdfDocument(inputBytes: pdfBytes);
    try {
      final extractor = syncfusion.PdfTextExtractor(document);
      return [
        for (var i = 0; i < document.pages.count; i++)
          {
            'page': i + 1,
            'text': extractor
                .extractText(startPageIndex: i, endPageIndex: i)
                .trim(),
          },
      ];
    } finally {
      document.dispose();
    }
  }
}
