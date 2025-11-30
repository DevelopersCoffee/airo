import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Centralized logging utility with support for different log levels
/// and crash reporting integration
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

  /// Set minimum log level
  static void setMinLevel(int level) {
    _minLevel = level;
  }

  /// Debug log - for development only
  static void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_levelDebug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Info log - general information
  static void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_levelInfo, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Warning log - potential issues
  static void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(_levelWarning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Error log - errors that need attention
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
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
  static void performance(String metric, int durationMs, {Map<String, dynamic>? details}) {
    final level = durationMs > 1000 ? _levelWarning : _levelDebug;
    _log(level, 'Performance: $metric took ${durationMs}ms ${details ?? ''}', tag: 'PERF');
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

  static String _getLevelName(int level) {
    switch (level) {
      case _levelDebug: return 'DEBUG';
      case _levelInfo: return 'INFO';
      case _levelWarning: return 'WARN';
      case _levelError: return 'ERROR';
      default: return 'LOG';
    }
  }

  static void _reportToCrashlytics(String message, Object error, StackTrace? stackTrace) {
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

