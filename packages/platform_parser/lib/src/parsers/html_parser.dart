
import 'dart:typed_data';
import 'parser.dart';

class HtmlParserProvider implements ParserProvider {
  @override bool supportsMime(String mimeType) => mimeType == 'text/html';
  @override bool supportsExtension(String extension) => extension == '.html';
  @override int get priority => 100;
  
  @override
  Future<AstNode> parse(Uint8List bytes, String mimeType) async {
    throw UnimplementedError();
  }
}
