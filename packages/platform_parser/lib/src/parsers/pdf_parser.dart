
import 'dart:typed_data';
import 'package:platform_provider/platform_provider.dart';
import 'package:platform_identity/platform_identity.dart';
import 'parser.dart';

class PdfParserProvider implements ParserProvider {
  @override
  ProviderDescriptor get descriptor => const ProviderDescriptor(
    id: ProviderId('pdf_parser'),
    version: '1.0.0',
    priority: 100,
    capabilities: ['parse'],
    supportedFormats: ['text/pdf'],
    supportedPlatforms: ['all'],
  );

  @override bool supportsMime(String mimeType) => mimeType == 'text/pdf';
  @override bool supportsExtension(String extension) => extension == '.pdf';
  
  @override
  Future<AstNode> parse(Uint8List bytes, String mimeType) async {
    throw UnimplementedError();
  }
}
