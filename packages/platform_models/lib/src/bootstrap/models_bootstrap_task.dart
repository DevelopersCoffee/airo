import 'package:platform_core/platform_core.dart';
import 'package:platform_models/src/catalog/model_catalog.dart';

class ModelsBootstrapTask implements BootstrapTask {

  const ModelsBootstrapTask({required this.catalog});
  final ModelCatalog catalog;

  @override
  String id() => 'models';

  @override
  Set<String> provides() => {'models_catalog'};

  @override
  Set<String> dependsOn() => {'logging', 'events', 'settings', 'downloads'};

  @override
  bool isLazy() => false;

  @override
  Future<Result<void>> initialize(BootstrapContext context) async {
    try {
      await catalog.initialize();
      return const Result.success(null);
    } catch (e) {
      return Result.fatalFailure(Exception('ModelsBootstrapTask failed: $e'));
    }
  }
}
