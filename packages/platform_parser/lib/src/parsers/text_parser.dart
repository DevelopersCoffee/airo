
import 'dart:typed_data';
import 'package:platform_pipeline/platform_pipeline.dart';
import 'parser.dart';

class TextParser implements Parser {
  @override
  Future<AstArtifact> parse(Uint8List bytes, String mimeType) async {
    return AstArtifact(
      id: 'txt-ast-1',
      version: '1.0',
      producer: 'TextParser',
      schema: 'AstSchema',
      checksum: 'chk',
    );
  }
}
