import 'dart:convert';
import '../contracts/log_formatter.dart';
import '../events/log_entry.dart';

class JsonFormatter implements LogFormatter {
  @override
  String format(LogEntry entry) {
    return jsonEncode({
      'timestamp': entry.timestamp.toIso8601String(),
      'level': entry.level.name,
      'category': entry.category.name,
      'message': entry.message,
      'correlationId': entry.context?.correlationId,
      'workspaceId': entry.context?.workspaceId,
      'sessionId': entry.context?.sessionId,
      'error': entry.error?.toString(),
      'metadata': entry.metadata?.toMap(),
    });
  }
}
