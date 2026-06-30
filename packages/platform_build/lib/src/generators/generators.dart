import '../templates/template_models.dart';

abstract interface class ProjectGenerator {
  TemplateModel generate(Map<String, dynamic> metadata);
}

abstract interface class FeatureGenerator implements ProjectGenerator {}
abstract interface class PluginGenerator implements ProjectGenerator {}
abstract interface class ToolGenerator implements ProjectGenerator {}
abstract interface class ProtocolGenerator implements ProjectGenerator {}
