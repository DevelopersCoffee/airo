import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceClass', () {
    test('detectTV returns tvLow for <= 1 GB', () {
      final dc = DeviceClass.detectTV(totalRamBytes: 1024 * 1024 * 1024);
      expect(dc, DeviceClass.tvLow);
    });

    test('detectTV returns tvMid for > 1 GB', () {
      final dc = DeviceClass.detectTV(totalRamBytes: 2 * 1024 * 1024 * 1024);
      expect(dc, DeviceClass.tvMid);
    });

    test('detectTV defaults to tvMid when RAM is null', () {
      final dc = DeviceClass.detectTV();
      expect(dc, DeviceClass.tvMid);
    });
  });

  group('MemoryBudget', () {
    test('forDevice returns a budget for every DeviceClass value', () {
      for (final dc in DeviceClass.values) {
        final budget = MemoryBudget.forDevice(dc);
        expect(budget.imageCacheBytes, greaterThan(0));
        expect(budget.imageCacheCount, greaterThan(0));
        expect(budget.maxChannelListSize, greaterThan(0));
        expect(budget.rssTargetBytes, greaterThan(0));
        expect(budget.rssPeakBytes, greaterThan(budget.rssTargetBytes));
      }
    });

    test('tvLow has the smallest image cache', () {
      final tvLow = MemoryBudget.forDevice(DeviceClass.tvLow);
      final desktop = MemoryBudget.forDevice(DeviceClass.desktop);
      expect(tvLow.imageCacheBytes, lessThan(desktop.imageCacheBytes));
    });

    test('desktop has the largest channel list limit', () {
      final desktop = MemoryBudget.forDevice(DeviceClass.desktop);
      for (final dc in DeviceClass.values) {
        if (dc == DeviceClass.desktop) continue;
        final other = MemoryBudget.forDevice(dc);
        expect(
          desktop.maxChannelListSize,
          greaterThanOrEqualTo(other.maxChannelListSize),
        );
      }
    });

    test('tvLow budget values match specification', () {
      const mb = 1024 * 1024;
      final budget = MemoryBudget.forDevice(DeviceClass.tvLow);
      expect(budget.imageCacheBytes, 30 * mb);
      expect(budget.imageCacheCount, 100);
      expect(budget.maxChannelListSize, 5000);
      expect(budget.rssTargetBytes, 200 * mb);
      expect(budget.rssPeakBytes, 300 * mb);
    });

    test('mobileHigh budget values match specification', () {
      const mb = 1024 * 1024;
      final budget = MemoryBudget.forDevice(DeviceClass.mobileHigh);
      expect(budget.imageCacheBytes, 100 * mb);
      expect(budget.imageCacheCount, 500);
      expect(budget.maxChannelListSize, 50000);
      expect(budget.rssTargetBytes, 400 * mb);
      expect(budget.rssPeakBytes, 600 * mb);
    });

    test('toString includes readable size info', () {
      final budget = MemoryBudget.forDevice(DeviceClass.desktop);
      final str = budget.toString();
      expect(str, contains('200 MB'));
      expect(str, contains('1000'));
      expect(str, contains('100000'));
    });
  });
}
