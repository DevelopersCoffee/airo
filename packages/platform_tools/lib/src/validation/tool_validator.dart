import 'package:platform_schemas/platform_schemas.dart';

class ToolValidator {
  bool validateRequest(ToolRequest request) {
    if (request.invocationId.isEmpty) return false;
    if (request.caller.isEmpty) return false;
    return true;
  }

  bool validateResult(ToolResult result) {
    if (result.status.isEmpty) return false;
    return true;
  }
}
