
import 'dart:typed_data';

class AstNode {
  final String type;
  final Map<String, dynamic> attributes;
  final List<AstNode> children;
  AstNode({required this.type, this.attributes = const {}, this.children = const []});
}

abstract class ParserProvider {
  bool supportsMime(String mimeType);
  bool supportsExtension(String extension);
  int get priority;
  Future<AstNode> parse(Uint8List bytes, String mimeType);
}
