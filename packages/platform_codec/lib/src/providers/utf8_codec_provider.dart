import 'dart:convert';
import 'dart:typed_data';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_provider/platform_provider.dart';
import '../codec.dart';

class Utf8CodecProvider implements CodecProvider<String> {
  @override
  ProviderDescriptor get descriptor => const ProviderDescriptor(
    id: ProviderId('utf8_codec'),
    version: '1.0.0',
    priority: 100,
    capabilities: ['encode', 'decode'],
    supportedFormats: ['text/plain'],
    supportedPlatforms: ['all'],
  );

  @override
  String decode(Uint8List bytes) {
    return utf8.decode(bytes);
  }

  @override
  Uint8List encode(String data) {
    return Uint8List.fromList(utf8.encode(data));
  }
}
