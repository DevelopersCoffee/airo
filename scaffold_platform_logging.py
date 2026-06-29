import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

base = 'packages/platform_logging/lib/src'

# Levels
create_file(f'{base}/levels/log_level.dart', '''enum LogLevel {
  trace,
  debug,
  info,
  warning,
  error,
  fatal;
  
  bool operator >=(LogLevel other) => index >= other.index;
}
''')

create_file(f'{base}/levels/log_category.dart', '''enum LogCategory {
  platform,
  runtime,
  storage,
  download,
  knowledge,
  memory,
  meeting,
  workflow,
  plugin,
  network,
  security,
  ui,
  performance,
  testing
}
''')

# Metadata and Context
create_file(f'{base}/context/log_metadata.dart', '''import 'package:equatable/equatable.dart';

class LogMetadata extends Equatable {
  final Map<String, dynamic> _data;

  const LogMetadata([Map<String, dynamic>? data]) : _data = data ?? const {};
  
  Map<String, dynamic> toMap() => Map.unmodifiable(_data);

  @override
  List<Object?> get props => [_data];
}
''')

create_file(f'{base}/context/log_context.dart', '''import 'package:equatable/equatable.dart';

class LogContext extends Equatable {
  final String? sessionId;
  final String? workspaceId;
  final String? conversationId;
  final String? requestId;
  final String? workflowId;
  final String? correlationId;

  const LogContext({
    this.sessionId,
    this.workspaceId,
    this.conversationId,
    this.requestId,
    this.workflowId,
    this.correlationId,
  });

  LogContext copyWith({
    String? sessionId,
    String? workspaceId,
    String? conversationId,
    String? requestId,
    String? workflowId,
    String? correlationId,
  }) {
    return LogContext(
      sessionId: sessionId ?? this.sessionId,
      workspaceId: workspaceId ?? this.workspaceId,
      conversationId: conversationId ?? this.conversationId,
      requestId: requestId ?? this.requestId,
      workflowId: workflowId ?? this.workflowId,
      correlationId: correlationId ?? this.correlationId,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    workspaceId,
    conversationId,
    requestId,
    workflowId,
    correlationId,
  ];
}
''')

create_file(f'{base}/context/log_context_provider_interface.dart', '''import 'log_context.dart';

abstract interface class LogContextProvider {
  LogContext get currentContext;
}
''')

# Events (LogEntry)
create_file(f'{base}/events/log_entry.dart', '''import 'package:freezed_annotation/freezed_annotation.dart';
import '../levels/log_level.dart';
import '../levels/log_category.dart';
import '../context/log_metadata.dart';
import '../context/log_context.dart';

part 'log_entry.freezed.dart';

@freezed
class LogEntry with _$LogEntry {
  const factory LogEntry({
    required DateTime timestamp,
    required LogLevel level,
    required LogCategory category,
    required String message,
    String? module,
    String? package,
    String? thread,
    Object? error,
    StackTrace? stackTrace,
    LogContext? context,
    LogMetadata? metadata,
  }) = _LogEntry;
}
''')

# Contracts (Interfaces)
create_file(f'{base}/contracts/logger.dart', '''import '../levels/log_level.dart';
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
''')

create_file(f'{base}/contracts/log_sink.dart', '''import '../events/log_entry.dart';

abstract interface class LogSink {
  void write(LogEntry entry);
  Future<void> flush();
  Future<void> close();
}
''')

create_file(f'{base}/contracts/log_formatter.dart', '''import '../events/log_entry.dart';

abstract interface class LogFormatter {
  String format(LogEntry entry);
}
''')

create_file(f'{base}/contracts/log_filter.dart', '''import '../events/log_entry.dart';

abstract interface class LogFilter {
  bool shouldLog(LogEntry entry);
}
''')

# Diagnostics
create_file(f'{base}/diagnostics/diagnostic_contracts.dart', '''abstract interface class DiagnosticCollector {
  Future<DiagnosticReport> collectDiagnostics();
}

enum HealthStatus {
  healthy,
  degraded,
  unhealthy,
  unknown
}

class DiagnosticSnapshot {
  final String component;
  final HealthStatus status;
  final Map<String, dynamic> metrics;
  
  const DiagnosticSnapshot(this.component, this.status, this.metrics);
}

class DiagnosticReport {
  final DateTime timestamp;
  final List<DiagnosticSnapshot> snapshots;
  
  const DiagnosticReport(this.timestamp, this.snapshots);
}

abstract interface class PerformanceMarker {
  void start(String operation);
  void finish(String operation);
}
''')

# Formatter implementations
create_file(f'{base}/formatter/human_readable_formatter.dart', '''import '../contracts/log_formatter.dart';
import '../events/log_entry.dart';

class HumanReadableFormatter implements LogFormatter {
  @override
  String format(LogEntry entry) {
    final buffer = StringBuffer();
    buffer.write('[${entry.timestamp.toIso8601String()}] ');
    buffer.write('[${entry.level.name.toUpperCase()}] ');
    buffer.write('[${entry.category.name}] ');
    
    if (entry.context?.correlationId != null) {
      buffer.write('[Trace: ${entry.context!.correlationId}] ');
    }
    
    buffer.write(entry.message);
    
    if (entry.error != null) {
      buffer.write('\\nError: ${entry.error}');
    }
    if (entry.stackTrace != null) {
      buffer.write('\\nStack: ${entry.stackTrace}');
    }
    return buffer.toString();
  }
}
''')

create_file(f'{base}/formatter/json_formatter.dart', '''import 'dart:convert';
import '../contracts/log_formatter.dart';
import '../events/log_entry.dart';

class JsonFormatter implements LogFormatter {
  @override
  String format(LogEntry entry) {
    return jsonEncode({
      'timestamp': entry.timestamp.toIso8601String(),
      'level': entry.level.name,
      'category': entry.category.name,
      'message': entry.message,
      'correlationId': entry.context?.correlationId,
      'workspaceId': entry.context?.workspaceId,
      'sessionId': entry.context?.sessionId,
      'error': entry.error?.toString(),
      'metadata': entry.metadata?.toMap(),
    });
  }
}
''')

# Sinks implementations
create_file(f'{base}/sinks/console_sink.dart', '''import 'dart:developer' as developer;
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
''')

create_file(f'{base}/sinks/memory_sink.dart', '''import '../contracts/log_sink.dart';
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
''')

# Filters implementations
create_file(f'{base}/filters/level_filter.dart', '''import '../contracts/log_filter.dart';
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
''')

create_file(f'{base}/filters/category_filter.dart', '''import '../contracts/log_filter.dart';
import '../events/log_entry.dart';
import '../levels/log_category.dart';

class CategoryFilter implements LogFilter {
  final Set<LogCategory> allowedCategories;

  const CategoryFilter(this.allowedCategories);

  @override
  bool shouldLog(LogEntry entry) {
    return allowedCategories.contains(entry.category);
  }
}
''')

# Logger Implementation
create_file(f'{base}/logger/platform_logger.dart', '''import '../contracts/logger.dart';
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
''')

# Bootstrap
create_file(f'{base}/bootstrap/logging_bootstrap_task.dart', '''import 'package:platform_core/platform_core.dart';
import '../sinks/console_sink.dart';
import '../filters/level_filter.dart';
import '../levels/log_level.dart';

class LoggingBootstrapTask implements BootstrapTask {
  @override
  String get name => 'PlatformLogging';

  @override
  BootstrapPhase get phase => BootstrapPhase.logging;

  @override
  Future<BootstrapResult> execute(BootstrapContext context) async {
    // In a real implementation we would register the logger into Riverpod here
    // But since Riverpod handles injection we just verify basic setup
    return const BootstrapResult.success(BootstrapPhase.logging);
  }
}
''')

# Providers
create_file(f'{base}/providers/logging_providers.dart', '''import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../contracts/logger.dart';
import '../contracts/log_sink.dart';
import '../contracts/log_filter.dart';
import '../context/log_context_provider_interface.dart';
import '../context/log_context.dart';
import '../diagnostics/diagnostic_contracts.dart';
import '../logger/platform_logger.dart';
import '../sinks/console_sink.dart';

class DefaultLogContextProvider implements LogContextProvider {
  @override
  LogContext get currentContext => const LogContext();
}

final logContextProvider = Provider<LogContextProvider>((ref) {
  return DefaultLogContextProvider();
});

final logSinksProvider = Provider<List<LogSink>>((ref) {
  return [ConsoleSink()];
});

final logFiltersProvider = Provider<List<LogFilter>>((ref) {
  return [];
});

final loggerProvider = Provider<Logger>((ref) {
  return PlatformLogger(
    sinks: ref.watch(logSinksProvider),
    filters: ref.watch(logFiltersProvider),
    contextProvider: ref.watch(logContextProvider),
  );
});

final diagnosticProvider = Provider<DiagnosticCollector>((ref) {
  throw UnimplementedError('DiagnosticCollector must be overridden');
});
''')

# Export file
create_file('packages/platform_logging/lib/platform_logging.dart', '''library platform_logging;

export 'src/bootstrap/logging_bootstrap_task.dart';
export 'src/context/log_context.dart';
export 'src/context/log_context_provider_interface.dart';
export 'src/context/log_metadata.dart';
export 'src/contracts/log_filter.dart';
export 'src/contracts/log_formatter.dart';
export 'src/contracts/log_sink.dart';
export 'src/contracts/logger.dart';
export 'src/diagnostics/diagnostic_contracts.dart';
export 'src/events/log_entry.dart';
export 'src/filters/category_filter.dart';
export 'src/filters/level_filter.dart';
export 'src/formatter/human_readable_formatter.dart';
export 'src/formatter/json_formatter.dart';
export 'src/levels/log_category.dart';
export 'src/levels/log_level.dart';
export 'src/logger/platform_logger.dart';
export 'src/providers/logging_providers.dart';
export 'src/sinks/console_sink.dart';
export 'src/sinks/memory_sink.dart';
''')

print("Created all platform_logging files.")
