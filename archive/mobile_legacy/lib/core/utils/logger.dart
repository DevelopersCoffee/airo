import 'dart:collection';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// A single log entry with timestamp and metadata.
class LogEntry {
  final DateTime timestamp;
  final int level;
  final String levelName;
  final String message;
  final String? tag;
  final String? error;
  final String? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.levelName,
    required this.message,
    this.tag,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[$levelName] ');
    if (tag != null) buffer.write('[$tag] ');
    buffer.write(message);
    if (error != null) buffer.write('\nError: $error');
    if (stackTrace != null) buffer.write('\nStack: $stackTrace');
    return buffer.toString();
  }
}

/// Centralized logging utility with support for different log levels,
/// crash reporting integration, and log buffer for bug reports.
class AppLogger {
  AppLogger._();

  static const String _name = 'AiroMoney';

  /// Log levels
  static const int _levelDebug = 0;
  static const int _levelInfo = 1;
  static const int _levelWarning = 2;
  static const int _levelError = 3;

  /// Minimum log level to output (configurable per environment)
  static int _minLevel = kDebugMode ? _levelDebug : _levelInfo;

  /// Maximum number of log entries to keep in buffer
  static const int _maxBufferSize = 500;

  /// Circular buffer for recent log entries (for bug reports)
  static final Queue<LogEntry> _logBuffer = Queue<LogEntry>();

  /// Set minimum log level
  static void setMinLevel(int level) {
    _minLevel = level;
  }

  /// Get recent log entries for bug reports.
  /// Returns logs from newest to oldest, limited to [count] entries.
  static List<LogEntry> getRecentLogs({int count = 100}) {
    final logs = _logBuffer.toList().reversed.take(count).toList();
    return logs;
  }

  /// Get recent logs formatted as a string for bug reports.
  static String getRecentLogsAsString({int count = 100}) {
    final logs = getRecentLogs(count: count);
    if (logs.isEmpty) return 'No logs available';
    return logs.map((e) => e.toString()).join('\n');
  }

  /// Get only error logs for bug reports.
  static String getErrorLogsAsString({int count = 50}) {
    final errorLogs = _logBuffer
        .where((e) => e.level >= _levelError)
        .toList()
        .reversed
        .take(count);
    if (errorLogs.isEmpty) return 'No error logs';
    return errorLogs.map((e) => e.toString()).join('\n');
  }

  /// Clear the log buffer.
  static void clearBuffer() {
    _logBuffer.clear();
  }

  /// Debug log - for development only
  static void debug(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(_levelDebug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Info log - general information
  static void info(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(_levelInfo, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Warning log - potential issues
  static void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      _levelWarning,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Error log - errors that need attention
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(_levelError, message, tag: tag, error: error, stackTrace: stackTrace);

    // In production, send to crash reporting service
    if (!kDebugMode && error != null) {
      _reportToCrashlytics(message, error, stackTrace);
    }
  }

  /// Log a database operation
  static void database(String operation, {String? details, int? durationMs}) {
    final msg = durationMs != null
        ? '$operation ($durationMs ms)${details != null ? ': $details' : ''}'
        : '$operation${details != null ? ': $details' : ''}';
    debug(msg, tag: 'DATABASE');
  }

  /// Log a sync operation
  static void sync(String message, {bool success = true}) {
    if (success) {
      info(message, tag: 'SYNC');
    } else {
      warning(message, tag: 'SYNC');
    }
  }

  /// Log an analytics event
  static void analytics(String event, {Map<String, dynamic>? params}) {
    debug('Event: $event ${params ?? ''}', tag: 'ANALYTICS');
    // TODO: Send to analytics service
  }

  /// Log a user action
  static void userAction(String action, {Map<String, dynamic>? details}) {
    info('Action: $action ${details ?? ''}', tag: 'USER');
  }

  /// Log performance metrics
  static void performance(
    String metric,
    int durationMs, {
    Map<String, dynamic>? details,
  }) {
    final level = durationMs > 1000 ? _levelWarning : _levelDebug;
    _log(
      level,
      'Performance: $metric took ${durationMs}ms ${details ?? ''}',
      tag: 'PERF',
    );
  }

  static void _log(
    int level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level < _minLevel) return;

    final levelName = _getLevelName(level);
    final fullTag = tag != null ? '$_name:$tag' : _name;
    final fullMessage = '[$levelName] $message';

    // Add to buffer for bug reports
    _addToBuffer(
      level: level,
      levelName: levelName,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );

    if (kDebugMode) {
      developer.log(
        fullMessage,
        name: fullTag,
        error: error,
        stackTrace: stackTrace,
        level: level * 500,
      );
    } else {
      // In release mode, use print for console output
      // Real apps would use a logging service
      // ignore: avoid_print
      print('$fullTag $fullMessage');
    }
  }

  static void _addToBuffer({
    required int level,
    required String levelName,
    required String message,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      levelName: levelName,
      message: message,
      tag: tag,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    _logBuffer.add(entry);

    // Keep buffer size under limit
    while (_logBuffer.length > _maxBufferSize) {
      _logBuffer.removeFirst();
    }
  }

  static String _getLevelName(int level) {
    switch (level) {
      case _levelDebug:
        return 'DEBUG';
      case _levelInfo:
        return 'INFO';
      case _levelWarning:
        return 'WARN';
      case _levelError:
        return 'ERROR';
      default:
        return 'LOG';
    }
  }

  static void _reportToCrashlytics(
    String message,
    Object error,
    StackTrace? stackTrace,
  ) {
    // TODO: Integrate with Firebase Crashlytics or similar service
    // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
  }
}

/// Extension for timing operations
extension LoggerTiming on Stopwatch {
  void logPerformance(String metric, {Map<String, dynamic>? details}) {
    stop();
    AppLogger.performance(metric, elapsedMilliseconds, details: details);
  }
}
