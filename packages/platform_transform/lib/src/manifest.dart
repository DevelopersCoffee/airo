import 'package:platform_pipeline/platform_pipeline.dart';
import 'package:platform_transform/platform_transform.dart';

class TransformManifest {
  const TransformManifest(this.id, this.configuration);
  final String id;
  final Map<String, dynamic> configuration;
}

abstract class PassFactory {
  TransformPass create(TransformManifest manifest);
}

abstract class TransformInstance implements TransformPass {
  String get id;
}
