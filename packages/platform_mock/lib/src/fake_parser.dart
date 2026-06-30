import 'package:platform_ast/platform_ast.dart';
import 'dart:typed_data';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_provider/platform_provider.dart';
import 'package:platform_parser/platform_parser.dart';
import 'package:platform_content/platform_content.dart';
import 'package:platform_pipeline/platform_pipeline.dart';

class FakeParser implements ParserProvider {
  @override
  ProviderDescriptor get descriptor => ProviderDescriptor(
    id: const ProviderId('mock_parser'),
    version: '1.0.0',
    priority: 10,
    capabilities: const ['parse_mock'],
    supportedFormats: const ['text/mock'],
    supportedPlatforms: const ['all'],
  );

  @override
  bool supportsExtension(String extension) => extension == '.mock';

  @override
  bool supportsMime(String mimeType) => mimeType == 'text/mock';

  @override
  Stream<ParserEvent> parse(RawArtifact artifact) async* {
    yield ParserEvent('open', {});
  }
),
      payload: Paragraph([])
    );
  }
}
