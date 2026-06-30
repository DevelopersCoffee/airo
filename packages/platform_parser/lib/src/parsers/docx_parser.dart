
import 'dart:typed_data';
import 'package:platform_pipeline/platform_pipeline.dart';
import 'parser.dart';

class DocxParser implements Parser {
  @override
  Future<AstArtifact> parse(Uint8List bytes, String mimeType) async {
    throw UnimplementedError('DOCX Parser coming soon');
  }
}
