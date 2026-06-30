import 'dart:convert';
import 'dart:typed_data';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_provider/platform_provider.dart';
import '../codec.dart';

class JsonCodecProvider implements CodecProvider<Map<String, dynamic>> {
  @override
  ProviderDescriptor get descriptor => const ProviderDescriptor(
    id: ProviderId('json_codec'),
    version: '1.0.0',
    priority: 100,
    capabilities: ['encode', 'decode'],
    supportedFormats: ['application/json'],
    supportedPlatforms: ['all'],
  );

  @override
  Map<String, dynamic> decode(Uint8List bytes) {
    return json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  @override
  Uint8List encode(Map<String, dynamic> data) {
    return Uint8List.fromList(utf8.encode(json.encode(data)));
  }
}
