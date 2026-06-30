import 'package:platform_schemas/platform_schemas.dart';

abstract interface class ProtocolRequest {
  String get id;
  Map<String, dynamic> get rawPayload;
}

abstract interface class ProtocolResponse {
  String get id;
  Map<String, dynamic> get rawPayload;
}

abstract interface class ProtocolSerializer {
  ProtocolRequest deserializeRequest(dynamic rawData);
  dynamic serializeResponse(ProtocolResponse response);
}

abstract interface class ProtocolAdapter {
  String get protocolName;
  String get version;
  
  ProtocolSerializer get serializer;
  
  /// Translates an external protocol request into a normalized ToolRequest
  ToolRequest translateRequest(ProtocolRequest request);
  
  /// Translates a normalized ToolResult into an external protocol response
  ProtocolResponse translateResponse(ProtocolRequest request, ToolResult result);
}
