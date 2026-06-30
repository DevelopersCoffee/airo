import 'package:platform_identity/platform_identity.dart';

class PipelineManifest {
  const PipelineManifest(this.id, this.stages);
  final String id;
  final List<String> stages;
}

class PipelineRegistry {
  final Map<String, PipelineManifest> _manifests = {};
  void register(PipelineManifest manifest) => _manifests[manifest.id] = manifest;
  PipelineManifest? get(String id) => _manifests[id];
}

abstract class PipelineLoader {
  Future<PipelineManifest> load(String uri);
}

abstract class PipelineRunner {
  Future<void> run(PipelineManifest manifest);
}
