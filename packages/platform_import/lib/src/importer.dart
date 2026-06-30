import 'dart:async';
import 'package:platform_pipeline/platform_pipeline.dart';
import 'package:platform_provider/platform_provider.dart';

class ImportJob {
  const ImportJob(this.uri, this.metadata);
  final String uri;
  final Map<String, dynamic> metadata;
}

abstract class DiscoveryProvider implements PlatformProvider {
  bool supports(String uri);
  Stream<ImportJob> discover(String uri);
}

abstract class ImporterProvider implements PlatformProvider {
  bool supports(ImportJob job);
  Stream<RawArtifact> importData(ImportJob job);
}
