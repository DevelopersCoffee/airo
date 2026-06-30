
import 'dart:typed_data';
import 'parser.dart';

class PdfParserProvider implements ParserProvider {
  @override bool supportsMime(String mimeType) => mimeType == 'text/pdf';
  @override bool supportsExtension(String extension) => extension == '.pdf';
  @override int get priority => 100;
  
  @override
  Future<AstNode> parse(Uint8List bytes, String mimeType) async {
    throw UnimplementedError();
  }
}
