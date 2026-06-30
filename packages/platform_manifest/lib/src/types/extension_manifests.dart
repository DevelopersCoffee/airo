import '../base/base_manifest.dart';

class PluginManifest implements ExtensionManifest {
  @override final String identifier;
  @override final String version;
  @override final List<String> dependencies;
  @override final List<String> capabilities;
  @override final List<String> permissions;
  @override final List<String> bootstrapTasks;
  @override final Map<String, dynamic> settings;
  @override final String minPlatformVersion;

  const PluginManifest({
    required this.identifier,
    required this.version,
    this.dependencies = const [],
    this.capabilities = const [],
    this.permissions = const [],
    this.bootstrapTasks = const [],
    this.settings = const {},
    required this.minPlatformVersion,
  });
}

class EngineManifest extends PluginManifest {
  const EngineManifest({
    required super.identifier,
    required super.version,
    super.dependencies,
    super.capabilities,
    super.permissions,
    super.bootstrapTasks,
    super.settings,
    required super.minPlatformVersion,
  });
}

class ToolManifest extends PluginManifest {
  const ToolManifest({
    required super.identifier,
    required super.version,
    super.dependencies,
    super.capabilities,
    super.permissions,
    super.bootstrapTasks,
    super.settings,
    required super.minPlatformVersion,
  });
}

class FeatureManifest extends PluginManifest {
  const FeatureManifest({
    required super.identifier,
    required super.version,
    super.dependencies,
    super.capabilities,
    super.permissions,
    super.bootstrapTasks,
    super.settings,
    required super.minPlatformVersion,
  });
}

class WorkflowManifest extends PluginManifest {
  const WorkflowManifest({
    required super.identifier,
    required super.version,
    super.dependencies,
    super.capabilities,
    super.permissions,
    super.bootstrapTasks,
    super.settings,
    required super.minPlatformVersion,
  });
}
