import 'package:freezed_annotation/freezed_annotation.dart';
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
