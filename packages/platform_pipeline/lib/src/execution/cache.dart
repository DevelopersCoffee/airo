import 'dart:async';
import 'package:platform_pipeline/platform_pipeline.dart';

abstract class ArtifactCache {
  Future<Artifact<dynamic>?> get(String checksum);
  Future<void> put(Artifact<dynamic> artifact);
}
