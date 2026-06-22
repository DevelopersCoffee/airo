/// Stub implementation of pdfx for lean Android variants.
library;

import 'dart:typed_data';

enum PdfPageImageFormat { png, jpeg }

class PdfPageImage {
  const PdfPageImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class PdfPage {
  const PdfPage({this.width = 1, this.height = 1});

  final double width;
  final double height;

  Future<PdfPageImage?> render({
    required double width,
    required double height,
    PdfPageImageFormat format = PdfPageImageFormat.png,
    String? backgroundColor,
  }) async => null;

  Future<void> close() async {}
}

class PdfDocument {
  const PdfDocument({this.pagesCount = 0});

  final int pagesCount;

  static Future<PdfDocument> openFile(String path) async => const PdfDocument();

  static Future<PdfDocument> openData(Uint8List data) async =>
      const PdfDocument();

  Future<PdfPage> getPage(int pageNumber) async => const PdfPage();

  Future<void> close() async {}
}
