import 'dart:typed_data';

import 'package:platform_pipeline/platform_pipeline.dart';

abstract class Parser {
  Future<AstArtifact> parse(Uint8List bytes, String mimeType);
}
