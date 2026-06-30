import 'dart:async';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_provider/platform_provider.dart';
import 'package:platform_content/platform_content.dart';
import '../importer.dart';

class S3ImporterProvider implements ImporterProvider {
  @override
  ProviderDescriptor get descriptor => const ProviderDescriptor(
    id: ProviderId('s3_importer'),
    version: '1.0.0',
    priority: 100,
    capabilities: ['import'],
    supportedFormats: ['any'],
    supportedPlatforms: ['all'],
  );

  @override
  bool supports(ImportJob job) => job.uri.startsWith('s3://');

  @override
  Stream<RawArtifact> importData(ImportJob job) async* {
    throw UnimplementedError();
  }
}
