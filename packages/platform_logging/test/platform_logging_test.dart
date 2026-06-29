import 'package:flutter_test/flutter_test.dart';
import 'package:platform_logging/platform_logging.dart';
import 'package:platform_core/platform_core.dart';
import 'dart:convert';

void main() {
  group('PlatformLogger', () {
    test('Logs are routed to sink and formatted as JSON', () {
      final memorySink = MemorySink();
      final formatter = JsonFormatter();
      
      final logger = PlatformLogger(
        sinks: [
          // Wrap the memory sink to capture formatting for the test
          _FormattingSinkWrapper(memorySink, formatter)
        ],
        filters: [],
        contextProvider: DefaultLogContextProvider(),
      );

      logger.info('Test message', category: LogCategory.testing);
      
      expect(memorySink.entries.length, 1);
      final entry = memorySink.entries.first;
      expect(entry.level, LogLevel.info);
      expect(entry.category, LogCategory.testing);
      expect(entry.message, 'Test message');
      
      // Formatting test validation happens inside the wrapper or directly
      final formattedString = formatter.format(entry);
      final decoded = jsonDecode(formattedString);
      expect(decoded['message'], 'Test message');
      expect(decoded['level'], 'info');
      expect(decoded['category'], 'testing');
    });

    test('Filters respect LogLevel boundaries', () {
      final memorySink = MemorySink();
      
      final logger = PlatformLogger(
        sinks: [memorySink],
        filters: [const LevelFilter(LogLevel.warning)],
      );

      logger.info('This should be filtered out');
      logger.error('This should be logged');

      expect(memorySink.entries.length, 1);
      expect(memorySink.entries.first.level, LogLevel.error);
    });

    test('CategoryFilter restricts logs correctly', () {
      final memorySink = MemorySink();
      
      final logger = PlatformLogger(
        sinks: [memorySink],
        filters: [const CategoryFilter({LogCategory.security, LogCategory.network})],
      );

      logger.info('Blocked log', category: LogCategory.ui);
      logger.info('Allowed log', category: LogCategory.security);

      expect(memorySink.entries.length, 1);
      expect(memorySink.entries.first.category, LogCategory.security);
    });
  });
}

class _FormattingSinkWrapper implements LogSink {
  final MemorySink inner;
  final LogFormatter formatter;

  _FormattingSinkWrapper(this.inner, this.formatter);

  @override
  void write(LogEntry entry) {
    inner.write(entry);
    // formatting is verified in test logic
  }

  @override
  Future<void> flush() => inner.flush();
  
  @override
  Future<void> close() => inner.close();
}
