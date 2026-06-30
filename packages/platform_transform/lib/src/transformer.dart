import 'dart:async';
import 'package:platform_pipeline/platform_pipeline.dart';
import 'package:platform_provider/platform_provider.dart';
import 'package:platform_ast/platform_ast.dart';

abstract class TransformPass implements PlatformProvider {
  Future<SemanticArtifact> apply(SemanticArtifact document);
}

class PassRegistry {
  final List<TransformPass> _passes = [];
  void register(TransformPass pass) => _passes.add(pass);
  List<TransformPass> get passes => _passes;
}

class TransformPipeline {
  TransformPipeline(this.registry);
  final PassRegistry registry;

  Future<NormalizedArtifact> execute(SemanticArtifact document) async {
    // Scaffold
    return NormalizedArtifact(
      id: document.id,
      version: document.version,
      producer: 'TransformPipeline',
      schema: 'normalized',
      checksum: document.checksum,
      metadata: document.metadata,
      payload: document.payload
    );
  }
}
