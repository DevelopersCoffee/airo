import 'dart:async';
import 'package:platform_pipeline/platform_pipeline.dart';
import 'package:platform_provider/platform_provider.dart';
import 'package:platform_ast/platform_ast.dart';

abstract class ParserProvider implements PlatformProvider {
  bool supports(RawArtifact artifact);
  Stream<ParserEvent> parse(RawArtifact artifact);
}

class AstBuilder {
  DocumentNode build(Stream<ParserEvent> events) {
    // Scaffold implementation
    return DocumentNode([]);;
  }
}
