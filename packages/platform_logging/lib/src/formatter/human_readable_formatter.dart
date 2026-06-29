import '../contracts/log_formatter.dart';
import '../events/log_entry.dart';

class HumanReadableFormatter implements LogFormatter {
  @override
  String format(LogEntry entry) {
    final buffer = StringBuffer();
    buffer.write('[${entry.timestamp.toIso8601String()}] ');
    buffer.write('[${entry.level.name.toUpperCase()}] ');
    buffer.write('[${entry.category.name}] ');
    
    if (entry.context?.correlationId != null) {
      buffer.write('[Trace: ${entry.context!.correlationId}] ');
    }
    
    buffer.write(entry.message);
    
    if (entry.error != null) {
      buffer.write('\nError: ${entry.error}');
    }
    if (entry.stackTrace != null) {
      buffer.write('\nStack: ${entry.stackTrace}');
    }
    return buffer.toString();
  }
}
