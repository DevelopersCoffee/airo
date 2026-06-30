import 'package:platform_registry/platform_registry.dart';

class DependencyResolver {
  List<ExtensionManifest> resolveInitializationOrder(List<ExtensionManifest> manifests) {
    final result = <ExtensionManifest>[];
    final visited = <String>{};
    final visiting = <String>{};
    final manifestMap = {for (final m in manifests) m.identifier: m};

    void visit(String id) {
      if (visited.contains(id)) return;
      if (visiting.contains(id)) throw StateError('Dependency cycle detected involving $id');

      visiting.add(id);

      final manifest = manifestMap[id];
      if (manifest == null) throw StateError('Missing dependency: $id');

      for (final dep in manifest.dependencies) {
        visit(dep);
      }

      visiting.remove(id);
      visited.add(id);
      result.add(manifest);
    }

    for (final m in manifests) {
      visit(m.identifier);
    }

    return result;
  }
}
