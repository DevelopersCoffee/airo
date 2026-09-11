import '../entities/document.dart';

/// Byte-to-page-text seam. Implementations live in `feature_anya`.
/// Core tests never call a PDF plugin — they feed [ExtractedPdfPage] text.
abstract class AnyaPdfTextExtractor {
  Future<List<ExtractedPdfPage>> extractPages(List<int> pdfBytes);
}
