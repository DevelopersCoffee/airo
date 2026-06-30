
import 'dart:typed_data';
import 'parser.dart';

class MarkdownParserProvider implements ParserProvider {
  @override bool supportsMime(String mimeType) => mimeType == 'text/markdown';
  @override bool supportsExtension(String extension) => extension == '.md';
  @override int get priority => 100;
  
  @override
  Future<AstNode> parse(Uint8List bytes, String mimeType) async {
    return AstNode(type: 'root');
  }
}
