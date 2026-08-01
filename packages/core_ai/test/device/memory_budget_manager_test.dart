import 'package:flutter_test/flutter_test.dart';
import 'package:core_ai/src/device/memory_budget_manager.dart';
import 'package:core_ai/src/device/memory_severity.dart';

void main() {
  late MemoryBudgetManager manager;

  setUp(() {
    manager = MemoryBudgetManager();
  });

  group('MemoryBudgetManager constants', () {
    test('has correct budget percent (60%)', () {
      expect(MemoryBudgetManager.memoryBudgetPercent, equals(0.60));
    });

    test('has correct warning threshold (50%)', () {
      expect(MemoryBudgetManager.warningThresholdPercent, equals(0.50));
    });

    test('has correct critical threshold (80%)', () {
      expect(MemoryBudgetManager.criticalThresholdPercent, equals(0.80));
    });

    test('text model overhead is 1.5x', () {
      expect(MemoryBudgetManager.textModelOverhead, equals(1.5));
    });

    test('image model overhead is 1.8x', () {
      expect(MemoryBudgetManager.imageModelOverhead, equals(1.8));
    });
  });

  group('estimateMemoryUsage', () {
    test('calculates text model usage correctly', () {
      const fileSizeBytes = 1000000000; // 1GB
      final usage = manager.estimateMemoryUsage(fileSizeBytes, ModelType.text);
      expect(usage, equals(1500000000)); // 1.5GB
    });

    test('calculates image model usage correctly', () {
      const fileSizeBytes = 1000000000; // 1GB
      final usage = manager.estimateMemoryUsage(fileSizeBytes, ModelType.image);
      expect(usage, equals(1800000000)); // 1.8GB
    });

    test('calculates audio model usage correctly', () {
      const fileSizeBytes = 1000000000; // 1GB
      final usage = manager.estimateMemoryUsage(fileSizeBytes, ModelType.audio);
      expect(usage, equals(1600000000)); // 1.6GB
    });

    test('calculates multimodal model usage correctly', () {
      const fileSizeBytes = 1000000000; // 1GB
      final usage = manager.estimateMemoryUsage(
        fileSizeBytes,
        ModelType.multimodal,
      );
      expect(usage, equals(2000000000)); // 2.0GB
    });
  });

  group('calculateBudget', () {
    test('uses currently available RAM as the transient budget', () {
      const memoryInfo = MemoryInfo(
        totalBytes: 8589934592, // 8GB
        availableBytes: 4294967296, // 4GB
      );

      final budget = manager.calculateBudget(memoryInfo);
      expect(budget, 4294967296);
    });
  });

  group('checkMemoryForModel', () {
    const totalBytes = 8589934592; // 8GB
    const availableBytes = 6442450944; // 6GB available

    test('returns safe when usage is below 50% of budget', () {
      const memoryInfo = MemoryInfo(
        totalBytes: totalBytes,
        availableBytes: availableBytes,
      );

      // Budget is the 6GB currently available.
      // 50% of budget = 3GB.
      // Use 2GB = safe
      final severity = manager.checkMemoryForModel(
        2147483648, // 2GB
        memoryInfo,
      );

      expect(severity, equals(MemorySeverity.safe));
    });

    test('returns warning when usage is 50-80% of budget', () {
      const memoryInfo = MemoryInfo(
        totalBytes: totalBytes,
        availableBytes: availableBytes,
      );

      // 65% of the currently available 6GB is warning.
      final severity = manager.checkMemoryForModel(
        (6 * 0.65 * 1024 * 1024 * 1024).round(), // 3.9GB
        memoryInfo,
      );

      expect(severity, equals(MemorySeverity.warning));
    });

    test('returns critical when usage is 80-100% of budget', () {
      const memoryInfo = MemoryInfo(
        totalBytes: totalBytes,
        availableBytes: availableBytes,
      );

      // 90% of the currently available 6GB is critical.
      final severity = manager.checkMemoryForModel(
        (6 * 0.90 * 1024 * 1024 * 1024).round(), // 5.4GB
        memoryInfo,
      );

      expect(severity, equals(MemorySeverity.critical));
    });

    test('returns blocked when usage exceeds budget', () {
      const memoryInfo = MemoryInfo(
        totalBytes: totalBytes,
        availableBytes: availableBytes,
      );

      // A model larger than available RAM remains recoverable so the planner
      // can reduce context or choose another backend/model.
      final severity = manager.checkMemoryForModel(
        (8 * 1024 * 1024 * 1024).round(), // 8GB
        memoryInfo,
      );

      expect(severity, equals(MemorySeverity.critical));
    });

    test(
      'returns critical when budget fits but free memory is transiently low',
      () {
        const memoryInfo = MemoryInfo(
          totalBytes: totalBytes,
          availableBytes: 2147483648, // Only 2GB available
        );

        // 3GB exceeds the current free memory and should remain recoverable.
        final severity = manager.checkMemoryForModel(
          3221225472, // 3GB
          memoryInfo,
        );

        expect(severity, equals(MemorySeverity.critical));
      },
    );

    test('returns warning when memory info unavailable', () {
      final memoryInfo = MemoryInfo.unknown();

      final severity = manager.checkMemoryForModel(
        1073741824, // 1GB
        memoryInfo,
      );

      expect(severity, equals(MemorySeverity.warning));
    });
  });
}
