import '../events/log_entry.dart';

abstract interface class LogSink {
  void write(LogEntry entry);
  Future<void> flush();
  Future<void> close();
}
