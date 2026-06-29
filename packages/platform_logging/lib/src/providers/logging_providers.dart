import 'package:flutter_riverpod/flutter_riverpod.dart';
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
