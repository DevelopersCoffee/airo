
import 'dart:typed_data';
import 'package:platform_provider/platform_provider.dart';
import 'package:platform_identity/platform_identity.dart';
import 'parser.dart';

class HtmlParserProvider implements ParserProvider {
  @override
  ProviderDescriptor get descriptor => const ProviderDescriptor(
    id: ProviderId('html_parser'),
    version: '1.0.0',
    priority: 100,
    capabilities: ['parse'],
    supportedFormats: ['text/html'],
    supportedPlatforms: ['all'],
  );

  @override bool supportsMime(String mimeType) => mimeType == 'text/html';
  @override bool supportsExtension(String extension) => extension == '.html';
  
  @override
  Future<AstNode> parse(Uint8List bytes, String mimeType) async {
    throw UnimplementedError();
  }
}
