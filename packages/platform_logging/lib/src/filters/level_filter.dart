import '../contracts/log_filter.dart';
import '../events/log_entry.dart';
import '../levels/log_level.dart';

class LevelFilter implements LogFilter {
  final LogLevel minLevel;

  const LevelFilter(this.minLevel);

  @override
  bool shouldLog(LogEntry entry) {
    return entry.level >= minLevel;
  }
}
