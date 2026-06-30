import 'package:platform_protocols/platform_protocols.dart';
import 'package:platform_schemas/platform_schemas.dart';

class McpProtocolRequest implements ProtocolRequest {
  @override
  final String id;
  @override
  final Map<String, dynamic> rawPayload;

  const McpProtocolRequest(this.id, this.rawPayload);
}

class McpProtocolResponse implements ProtocolResponse {
  @override
  final String id;
  @override
  final Map<String, dynamic> rawPayload;

  const McpProtocolResponse(this.id, this.rawPayload);
}

class McpSerializer implements ProtocolSerializer {
  @override
  ProtocolRequest deserializeRequest(dynamic rawData) {
    if (rawData is! Map<String, dynamic>) {
      throw ArgumentError('MCP request must be a JSON object');
    }
    final id = rawData['id']?.toString() ?? '';
    return McpProtocolRequest(id, rawData);
  }

  @override
  dynamic serializeResponse(ProtocolResponse response) {
    return response.rawPayload;
  }
}

class McpAdapter implements ProtocolAdapter {
  @override
  final String protocolName = 'mcp';
  
  @override
  final String version = '1.0';

  @override
  final ProtocolSerializer serializer = McpSerializer();

  @override
  ToolRequest translateRequest(ProtocolRequest request) {
    final params = request.rawPayload['params'] as Map<String, dynamic>? ?? {};
    final toolName = params['name'] as String? ?? 'unknown';
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};

    return ToolRequest(
      invocationId: request.id,
      caller: 'mcp_client',
      workspaceId: 'default',
      sessionId: 'mcp_session',
      timestamp: DateTime.now(),
      payload: {
        'tool': toolName,
        'arguments': arguments,
      },
    );
  }

  @override
  ProtocolResponse translateResponse(ProtocolRequest request, ToolResult result) {
    final responsePayload = {
      'jsonrpc': '2.0',
      'id': request.id,
      'result': {
        'status': result.status,
        'data': result.payload,
        'diagnostics': result.diagnostics,
      }
    };

    return McpProtocolResponse(request.id, responsePayload);
  }
}
