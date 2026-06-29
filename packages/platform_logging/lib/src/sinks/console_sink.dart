import 'dart:developer' as developer;
import '../contracts/log_sink.dart';
import '../contracts/log_formatter.dart';
import '../events/log_entry.dart';
import '../formatter/human_readable_formatter.dart';

class ConsoleSink implements LogSink {
  final LogFormatter formatter;

  ConsoleSink({LogFormatter? formatter}) : formatter = formatter ?? HumanReadableFormatter();

  @override
  void write(LogEntry entry) {
    final formatted = formatter.format(entry);
    developer.log(
      formatted,
      time: entry.timestamp,
      level: entry.level.index * 100, // Roughly maps to dart:developer levels
      name: entry.category.name,
      error: entry.error,
      stackTrace: entry.stackTrace,
    );
    // Fallback if not attached to DevTools
    print(formatted);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}
