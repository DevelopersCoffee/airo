import '../events/log_entry.dart';

abstract interface class LogFormatter {
  String format(LogEntry entry);
}
