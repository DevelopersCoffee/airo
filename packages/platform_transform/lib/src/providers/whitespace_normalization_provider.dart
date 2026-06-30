import 'dart:async';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_provider/platform_provider.dart';
import 'package:platform_content/platform_content.dart';
import '../transformer.dart';

import 'package:platform_pipeline/platform_pipeline.dart';
class WhitespaceNormalizationProvider implements TransformPass {
  @override
  ProviderDescriptor get descriptor => const ProviderDescriptor(
    id: ProviderId('whitespace_normalization_transform'),
    version: '1.0.0',
    priority: 100,
    capabilities: ['transform'],
    supportedFormats: ['any'],
    supportedPlatforms: ['all'],
  );

  @override
  Future<SemanticArtifact> apply(SemanticArtifact document) async {
    throw UnimplementedError();
  }
}
