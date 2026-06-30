import 'package:platform_schemas/platform_schemas.dart';
import 'package:platform_registry/platform_registry.dart';

abstract interface class Tool {
  ToolManifest get manifest;
  Future<ToolResult> execute(ExecutionContext context);
  Stream<ToolEvent> executeStream(ExecutionContext context);
}
