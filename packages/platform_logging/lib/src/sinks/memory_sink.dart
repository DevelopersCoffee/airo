import '../contracts/log_sink.dart';
import '../events/log_entry.dart';

class MemorySink implements LogSink {
  final List<LogEntry> _entries = [];
  final int maxEntries;

  MemorySink({this.maxEntries = 1000});

  List<LogEntry> get entries => List.unmodifiable(_entries);

  @override
  void write(LogEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    _entries.clear();
  }
}
