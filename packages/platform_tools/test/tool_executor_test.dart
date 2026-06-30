import 'package:flutter_test/flutter_test.dart';
import 'package:platform_manifest/platform_manifest.dart';
import 'package:platform_schemas/platform_schemas.dart';
import 'package:platform_tools/platform_tools.dart';

class FakeTool implements Tool {
  final bool shouldSucceed;
  final ToolManifest _manifest;

  FakeTool(this._manifest, {this.shouldSucceed = true});

  @override
  ToolManifest get manifest => _manifest;

  @override
  Future<ToolResult> execute(ExecutionContext context) async {
    if (!shouldSucceed) {
      return const ToolResult(
        status: '', // Invalid result status
        payload: {},
        diagnostics: {},
        executionTime: Duration.zero,
      );
    }
    return const ToolResult(
      status: 'success',
      payload: {},
      diagnostics: {},
      executionTime: Duration(milliseconds: 10),
    );
  }

  @override
  Stream<ToolEvent> executeStream(ExecutionContext context) async* {
    yield ToolEvent(
      type: 'chunk',
      data: {},
      timestamp: DateTime.now(),
    );
  }
}

void main() {
  late ToolValidator validator;
  late ToolPermissionChecker permissionChecker;
  late ToolExecutor executor;

  setUp(() {
    validator = ToolValidator();
    permissionChecker = ToolPermissionChecker();
    executor = ToolExecutor(validator, permissionChecker);
  });

  test('executor validates request, checks permissions, and validates result', () async {
    const manifest = ToolManifest(
      identifier: 'fake.tool',
      version: '1.0',
      permissions: ['read_files'],
      minPlatformVersion: '1.0'
    );
    
    final tool = FakeTool(manifest);
    
    final request = ToolRequest(
      invocationId: 'req1',
      caller: 'test',
      workspaceId: 'w1',
      sessionId: 's1',
      timestamp: DateTime.now(),
      payload: {},
    );

    final context = ExecutionContext(
      request: request,
      protocol: const ProtocolDescriptor(protocolName: 'test', protocolVersion: '1.0'),
      workspace: const WorkspaceContext(workspaceId: 'w1', workspacePath: '/w1'),
      user: const UserContext(userId: 'u1', role: 'admin'),
      permissions: const PermissionContext(grantedPermissions: ['read_files']),
      cancellation: CancellationToken(),
      diagnostics: DiagnosticsCollector(),
    );

    final result = await executor.execute(tool, context);
    expect(result.status, 'success');
  });

  test('executor throws on missing permission', () async {
    const manifest = ToolManifest(
      identifier: 'fake.tool',
      version: '1.0',
      permissions: ['read_files'],
      minPlatformVersion: '1.0'
    );
    
    final tool = FakeTool(manifest);
    
    final request = ToolRequest(
      invocationId: 'req1',
      caller: 'test',
      workspaceId: 'w1',
      sessionId: 's1',
      timestamp: DateTime.now(),
      payload: {},
    );

    final context = ExecutionContext(
      request: request,
      protocol: const ProtocolDescriptor(protocolName: 'test', protocolVersion: '1.0'),
      workspace: const WorkspaceContext(workspaceId: 'w1', workspacePath: '/w1'),
      user: const UserContext(userId: 'u1', role: 'admin'),
      permissions: const PermissionContext(grantedPermissions: []),
      cancellation: CancellationToken(),
      diagnostics: DiagnosticsCollector(),
    );

    expect(
      () => executor.execute(tool, context),
      throwsStateError,
    );
  });
  
  test('executor throws on invalid request schema', () async {
    const manifest = ToolManifest(
      identifier: 'fake.tool',
      version: '1.0',
      permissions: [],
      minPlatformVersion: '1.0'
    );
    
    final tool = FakeTool(manifest);
    
    final request = ToolRequest(
      invocationId: '',
      caller: 'test',
      workspaceId: 'w1',
      sessionId: 's1',
      timestamp: DateTime.now(),
      payload: {},
    );

    final context = ExecutionContext(
      request: request,
      protocol: const ProtocolDescriptor(protocolName: 'test', protocolVersion: '1.0'),
      workspace: const WorkspaceContext(workspaceId: 'w1', workspacePath: '/w1'),
      user: const UserContext(userId: 'u1', role: 'admin'),
      permissions: const PermissionContext(grantedPermissions: []),
      cancellation: CancellationToken(),
      diagnostics: DiagnosticsCollector(),
    );

    expect(
      () => executor.execute(tool, context),
      throwsArgumentError,
    );
  });

  test('executor throws on invalid result schema', () async {
    const manifest = ToolManifest(
      identifier: 'fake.tool',
      version: '1.0',
      permissions: [],
      minPlatformVersion: '1.0'
    );
    
    final tool = FakeTool(manifest, shouldSucceed: false);
    
    final request = ToolRequest(
      invocationId: 'req1',
      caller: 'test',
      workspaceId: 'w1',
      sessionId: 's1',
      timestamp: DateTime.now(),
      payload: {},
    );

    final context = ExecutionContext(
      request: request,
      protocol: const ProtocolDescriptor(protocolName: 'test', protocolVersion: '1.0'),
      workspace: const WorkspaceContext(workspaceId: 'w1', workspacePath: '/w1'),
      user: const UserContext(userId: 'u1', role: 'admin'),
      permissions: const PermissionContext(grantedPermissions: []),
      cancellation: CancellationToken(),
      diagnostics: DiagnosticsCollector(),
    );

    expect(
      () => executor.execute(tool, context),
      throwsStateError,
    );
  });
}
