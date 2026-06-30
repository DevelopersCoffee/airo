import 'dart:typed_data';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_provider/platform_provider.dart';
import '../codec.dart';

class Utf16CodecProvider implements CodecProvider<dynamic> {
  @override
  ProviderDescriptor get descriptor => const ProviderDescriptor(
    id: ProviderId('utf16_codec'),
    version: '1.0.0',
    priority: 100,
    capabilities: ['encode', 'decode'],
    supportedFormats: ['application/utf16'],
    supportedPlatforms: ['all'],
  );

  @override
  dynamic decode(Uint8List bytes) {
    throw UnimplementedError();
  }

  @override
  Uint8List encode(dynamic data) {
    throw UnimplementedError();
  }
}
