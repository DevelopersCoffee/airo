import 'dart:io';
import 'dart:typed_data';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_provider/platform_provider.dart';
import '../importer.dart';

class FilesystemImporterProvider implements ImporterProvider {
  @override
  ProviderDescriptor get descriptor => const ProviderDescriptor(
    id: ProviderId('filesystem_importer'),
    version: '1.0.0',
    priority: 100,
    capabilities: ['import'],
    supportedFormats: ['file'],
    supportedPlatforms: ['android', 'ios', 'macos', 'windows', 'linux'],
  );

  @override
  bool supports(String uri) {
    return uri.startsWith('file://') || uri.startsWith('/');
  }

  @override
  Future<Uint8List> importData(String uri) async {
    final path = uri.startsWith('file://') ? uri.replaceFirst('file://', '') : uri;
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('File not found: $path');
    }
    return file.readAsBytes();
  }
}
