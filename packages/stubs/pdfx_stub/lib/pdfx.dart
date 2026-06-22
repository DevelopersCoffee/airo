library;

import 'dart:typed_data';

class PdfDocument {
  PdfDocument._();

  int get pagesCount => 0;

  static Future<PdfDocument> openFile(String path) async => PdfDocument._();

  static Future<PdfDocument> openData(Uint8List data) async => PdfDocument._();

  Future<PdfPage> getPage(int pageNumber) async => PdfPage._();

  Future<void> close() async {}
}

class PdfPage {
  PdfPage._();

  double get width => 1;
  double get height => 1;

  Future<PdfPageImage?> render({
    required double width,
    required double height,
    required PdfPageImageFormat format,
    String? backgroundColor,
  }) async => null;

  Future<void> close() async {}
}

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

enum PdfPageImageFormat { png }
