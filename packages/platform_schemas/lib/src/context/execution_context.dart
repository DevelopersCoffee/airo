import '../tool/tool_schemas.dart';

class ProtocolDescriptor {

  const ProtocolDescriptor({
    required this.protocolName,
    required this.protocolVersion,
  });
  final String protocolName;
  final String protocolVersion;
}

class WorkspaceContext {

  const WorkspaceContext({
    required this.workspaceId,
    required this.workspacePath,
  });
  final String workspaceId;
  final String workspacePath;
}

class UserContext {

  const UserContext({
    required this.userId,
    required this.role,
  });
  final String userId;
  final String role;
}

class PermissionContext {

  const PermissionContext({
    required this.grantedPermissions,
  });
  final List<String> grantedPermissions;
}

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class DiagnosticsCollector {
  final Map<String, dynamic> _diagnostics = {};

  void record(String key, dynamic value) {
    _diagnostics[key] = value;
  }

  Map<String, dynamic> getDiagnostics() => Map.unmodifiable(_diagnostics);
}

class ExecutionContext {

  const ExecutionContext({
    required this.request,
    required this.protocol,
    required this.workspace,
    required this.user,
    required this.permissions,
    required this.cancellation,
    required this.diagnostics,
  });
  final ToolRequest request;
  final ProtocolDescriptor protocol;
  final WorkspaceContext workspace;
  final UserContext user;
  final PermissionContext permissions;
  final CancellationToken cancellation;
  final DiagnosticsCollector diagnostics;
}
