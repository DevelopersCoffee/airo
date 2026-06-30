
import 'dart:typed_data';
import 'parser.dart';

class DocxParserProvider implements ParserProvider {
  @override bool supportsMime(String mimeType) => mimeType == 'text/docx';
  @override bool supportsExtension(String extension) => extension == '.docx';
  @override int get priority => 100;
  
  @override
  Future<AstNode> parse(Uint8List bytes, String mimeType) async {
    throw UnimplementedError();
  }
}
