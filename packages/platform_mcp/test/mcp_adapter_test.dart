import 'package:flutter_test/flutter_test.dart';
import 'package:platform_mcp/platform_mcp.dart';
import 'package:platform_schemas/platform_schemas.dart';

void main() {
  test('McpAdapter translates requests and responses correctly', () {
    final adapter = McpAdapter();
    
    // 1. Inbound JSON from MCP Transport
    final rawMcpRequest = {
      'jsonrpc': '2.0',
      'id': '123',
      'method': 'tools/call',
      'params': {
        'name': 'read_file',
        'arguments': {
          'path': '/tmp/test.txt',
        },
      },
    };

    // 2. Protocol parsing
    final protocolReq = adapter.serializer.deserializeRequest(rawMcpRequest);
    expect(protocolReq.id, '123');

    // 3. Translation to ToolRequest
    final toolReq = adapter.translateRequest(protocolReq);
    expect(toolReq.invocationId, '123');
    expect(toolReq.payload['tool'], 'read_file');
    expect((toolReq.payload['arguments'] as Map)['path'], '/tmp/test.txt');

    // 4. Simulate Execution result
    const toolResult = ToolResult(
      status: 'success',
      payload: {'content': 'hello'},
      diagnostics: {},
      executionTime: Duration(milliseconds: 10),
    );

    // 5. Translation to ProtocolResponse
    final protocolRes = adapter.translateResponse(protocolReq, toolResult);
    expect(protocolRes.id, '123');
    
    // 6. Serialization back to JSON
    final rawMcpResponse = adapter.serializer.serializeResponse(protocolRes);
    expect(rawMcpResponse['result']['status'], 'success');
    expect(rawMcpResponse['result']['data']['content'], 'hello');
  });
}
