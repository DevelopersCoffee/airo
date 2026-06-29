import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdfx/pdfx.dart';

class RenderedPdfPage {
  final int pageNumber;
  final Uint8List bytes;
  final int? width;
  final int? height;
  final String mimeType;

  const RenderedPdfPage({
    required this.pageNumber,
    required this.bytes,
    this.width,
    this.height,
    this.mimeType = 'image/png',
  });
}

abstract class ReceiptPdfRenderer {
  Future<List<RenderedPdfPage>> renderFile(File pdfFile);

  Future<List<RenderedPdfPage>> renderBytes(List<int> bytes);
}

class PdfxReceiptPdfRenderer implements ReceiptPdfRenderer {
  final double maxPageDimension;

  const PdfxReceiptPdfRenderer({this.maxPageDimension = 1600});

  @override
  Future<List<RenderedPdfPage>> renderFile(File pdfFile) async {
    final document = await PdfDocument.openFile(pdfFile.path);
    return _renderDocument(document);
  }

  @override
  Future<List<RenderedPdfPage>> renderBytes(List<int> bytes) async {
    final document = await PdfDocument.openData(Uint8List.fromList(bytes));
    return _renderDocument(document);
  }

  Future<List<RenderedPdfPage>> _renderDocument(PdfDocument document) async {
    final renderedPages = <RenderedPdfPage>[];
    try {
      for (
        var pageNumber = 1;
        pageNumber <= document.pagesCount;
        pageNumber++
      ) {
        final page = await document.getPage(pageNumber);
        try {
          final longestSide = math.max(page.width, page.height);
          final scale = maxPageDimension / longestSide;
          final renderWidth = (page.width * scale).roundToDouble();
          final renderHeight = (page.height * scale).roundToDouble();
          final image = await page.render(
            width: renderWidth,
            height: renderHeight,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (image == null) {
            throw StateError('Failed to render PDF page $pageNumber');
          }
          renderedPages.add(
            RenderedPdfPage(
              pageNumber: pageNumber,
              bytes: image.bytes,
              width: image.width,
              height: image.height,
            ),
          );
        } finally {
          await page.close();
        }
      }
    } finally {
      await document.close();
    }
    return renderedPages;
  }
}
