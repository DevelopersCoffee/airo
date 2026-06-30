import 'package:platform_ast/platform_ast.dart';
import 'package:platform_pipeline/platform_pipeline.dart';
import 'dart:async';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_provider/platform_provider.dart';
import 'package:platform_content/platform_content.dart';
import 'parser.dart';

class PdfiumParserProvider implements ParserProvider {
  @override
  ProviderDescriptor get descriptor => const ProviderDescriptor(
    id: ProviderId('pdfium_parser'),
    version: '1.0.0',
    priority: 100,
    capabilities: ['parse'],
    supportedFormats: ['any'],
    supportedPlatforms: ['all'],
  );

  @override
  bool supports(RawArtifact artifact) => false;

  @override
  Stream<ParserEvent> parse(RawArtifact artifact) async* {
    throw UnimplementedError();
  }
}
