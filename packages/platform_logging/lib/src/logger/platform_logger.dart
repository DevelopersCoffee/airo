import '../contracts/logger.dart';
import '../contracts/log_sink.dart';
import '../contracts/log_filter.dart';
import '../events/log_entry.dart';
import '../levels/log_level.dart';
import '../levels/log_category.dart';
import '../context/log_metadata.dart';
import '../context/log_context_provider_interface.dart';

class PlatformLogger implements Logger {
  final List<LogSink> _sinks;
  final List<LogFilter> _filters;
  final LogContextProvider? _contextProvider;
  
  PlatformLogger({
    required List<LogSink> sinks,
    List<LogFilter> filters = const [],
    LogContextProvider? contextProvider,
  }) : _sinks = sinks,
       _filters = filters,
       _contextProvider = contextProvider;

  void _log(LogLevel level, String message, LogCategory category, Object? error, StackTrace? stackTrace, LogMetadata? metadata) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
      context: _contextProvider?.currentContext,
    );

    for (final filter in _filters) {
      if (!filter.shouldLog(entry)) return;
    }

    for (final sink in _sinks) {
      sink.write(entry);
    }
  }

  @override
  void trace(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) =>
      _log(LogLevel.trace, message, category, error, stackTrace, metadata);

  @override
  void debug(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) =>
      _log(LogLevel.debug, message, category, error, stackTrace, metadata);

  @override
  void info(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) =>
      _log(LogLevel.info, message, category, error, stackTrace, metadata);

  @override
  void warn(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) =>
      _log(LogLevel.warning, message, category, error, stackTrace, metadata);

  @override
  void error(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) =>
      _log(LogLevel.error, message, category, error, stackTrace, metadata);

  @override
  void fatal(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) =>
      _log(LogLevel.fatal, message, category, error, stackTrace, metadata);
}
