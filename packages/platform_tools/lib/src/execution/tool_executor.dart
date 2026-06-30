import 'package:platform_schemas/platform_schemas.dart';

import '../api/tool.dart';
import '../permissions/tool_permission_checker.dart';
import '../validation/tool_validator.dart';

class ToolExecutor {

  ToolExecutor(this._validator, this._permissionChecker);
  final ToolValidator _validator;
  final ToolPermissionChecker _permissionChecker;

  Future<ToolResult> execute(
    Tool tool,
    ExecutionContext context,
  ) async {
    // 1. Schema Validation
    if (!_validator.validateRequest(context.request)) {
      throw ArgumentError('Invalid ToolRequest schema');
    }

    // 2. Permission Check
    if (!_permissionChecker.checkPermissions(tool.manifest, context.permissions.grantedPermissions)) {
      throw StateError('Permission denied for tool execution');
    }

    // 3. Execution
    final stopwatch = Stopwatch()..start();
    final result = await tool.execute(context);
    stopwatch.stop();

    // 4. Result Validation
    if (!_validator.validateResult(result)) {
      throw StateError('Invalid ToolResult schema produced');
    }

    return result;
  }
}
