import '../tool/tool_schemas.dart';

class ProtocolDescriptor {
  final String protocolName;
  final String protocolVersion;

  const ProtocolDescriptor({
    required this.protocolName,
    required this.protocolVersion,
  });
}

class WorkspaceContext {
  final String workspaceId;
  final String workspacePath;

  const WorkspaceContext({
    required this.workspaceId,
    required this.workspacePath,
  });
}

class UserContext {
  final String userId;
  final String role;

  const UserContext({
    required this.userId,
    required this.role,
  });
}

class PermissionContext {
  final List<String> grantedPermissions;

  const PermissionContext({
    required this.grantedPermissions,
  });
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
  final ToolRequest request;
  final ProtocolDescriptor protocol;
  final WorkspaceContext workspace;
  final UserContext user;
  final PermissionContext permissions;
  final CancellationToken cancellation;
  final DiagnosticsCollector diagnostics;

  const ExecutionContext({
    required this.request,
    required this.protocol,
    required this.workspace,
    required this.user,
    required this.permissions,
    required this.cancellation,
    required this.diagnostics,
  });
}
