import '../levels/log_category.dart';
import '../context/log_metadata.dart';

abstract interface class Logger {
  void trace(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata});
  void debug(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata});
  void info(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata});
  void warn(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata});
  void error(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata});
  void fatal(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata});
}
