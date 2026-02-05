import 'package:flutter_test/flutter_test.dart';
import 'package:core_ai/src/device/memory_severity.dart';

void main() {
  group('MemorySeverity', () {
    test('safe level allows loading', () {
      expect(MemorySeverity.safe.canLoad, isTrue);
      expect(MemorySeverity.safe.shouldWarn, isFalse);
      expect(MemorySeverity.safe.isRisky, isFalse);
    });

    test('warning level allows loading with warning', () {
      expect(MemorySeverity.warning.canLoad, isTrue);
      expect(MemorySeverity.warning.shouldWarn, isTrue);
      expect(MemorySeverity.warning.isRisky, isFalse);
    });

    test('critical level allows loading with warning and is risky', () {
      expect(MemorySeverity.critical.canLoad, isTrue);
      expect(MemorySeverity.critical.shouldWarn, isTrue);
      expect(MemorySeverity.critical.isRisky, isTrue);
    });

    test('blocked level does not allow loading', () {
      expect(MemorySeverity.blocked.canLoad, isFalse);
      expect(MemorySeverity.blocked.shouldWarn, isFalse);
      expect(MemorySeverity.blocked.isRisky, isTrue);
    });

    test('all levels have title and description', () {
      for (final severity in MemorySeverity.values) {
        expect(severity.title, isNotEmpty);
        expect(severity.description, isNotEmpty);
      }
    });
  });

  group('MemoryInfo', () {
    test('calculates usage correctly', () {
      const info = MemoryInfo(
        totalBytes: 8 * 1024 * 1024 * 1024, // 8GB
        availableBytes: 4 * 1024 * 1024 * 1024, // 4GB
      );

      expect(info.usedBytes, equals(4 * 1024 * 1024 * 1024));
      expect(info.usagePercent, closeTo(0.5, 0.001));
      expect(info.availablePercent, closeTo(0.5, 0.001));
    });

    test('creates from megabytes', () {
      final info = MemoryInfo.fromMegabytes(
        totalMB: 4096,
        availableMB: 2048,
      );

      expect(info.totalMB, closeTo(4096, 1));
      expect(info.availableMB, closeTo(2048, 1));
      expect(info.totalGB, closeTo(4, 0.01));
    });

    test('unknown factory creates zero values', () {
      final info = MemoryInfo.unknown();

      expect(info.totalBytes, equals(0));
      expect(info.availableBytes, equals(0));
      expect(info.isAvailable, isFalse);
    });

    test('isAvailable returns true when totalBytes > 0', () {
      const info = MemoryInfo(totalBytes: 1024, availableBytes: 512);
      expect(info.isAvailable, isTrue);
    });

    test('calculates gigabytes correctly', () {
      const info = MemoryInfo(
        totalBytes: 8589934592, // 8GB in bytes
        availableBytes: 4294967296, // 4GB in bytes
      );

      expect(info.totalGB, closeTo(8.0, 0.01));
      expect(info.availableGB, closeTo(4.0, 0.01));
    });

    test('toString formats correctly', () {
      const info = MemoryInfo(
        totalBytes: 8589934592,
        availableBytes: 4294967296,
      );

      final str = info.toString();
      expect(str, contains('8.0GB'));
      expect(str, contains('4.0GB'));
      expect(str, contains('50.0%'));
    });

    test('equality works correctly', () {
      const info1 = MemoryInfo(totalBytes: 1024, availableBytes: 512);
      const info2 = MemoryInfo(totalBytes: 1024, availableBytes: 512);
      const info3 = MemoryInfo(totalBytes: 2048, availableBytes: 512);

      expect(info1, equals(info2));
      expect(info1, isNot(equals(info3)));
      expect(info1.hashCode, equals(info2.hashCode));
    });

    test('handles zero totalBytes without division error', () {
      const info = MemoryInfo(totalBytes: 0, availableBytes: 0);

      expect(info.usagePercent, equals(0.0));
      expect(info.availablePercent, equals(0.0));
    });
  });
}

