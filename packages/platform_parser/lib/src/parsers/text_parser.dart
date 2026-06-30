
import 'dart:typed_data';
import 'parser.dart';

class TextParserProvider implements ParserProvider {
  @override bool supportsMime(String mimeType) => mimeType == 'text/text';
  @override bool supportsExtension(String extension) => extension == '.text';
  @override int get priority => 100;
  
  @override
  Future<AstNode> parse(Uint8List bytes, String mimeType) async {
    throw UnimplementedError();
  }
}
