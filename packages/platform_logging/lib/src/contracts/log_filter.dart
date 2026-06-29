import '../events/log_entry.dart';

abstract interface class LogFilter {
  bool shouldLog(LogEntry entry);
}
