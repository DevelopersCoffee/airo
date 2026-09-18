import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  group('platform_epg shim', () {
    test('re-exports EmptyCompactEpgRepository from airo_epg', () {
      final repository = EmptyCompactEpgRepository();
      expect(repository, isA<CompactEpgRepository>());
    });

    test('re-exports CompactEpgSlice availability logic', () {
      final now = DateTime.utc(2026, 1, 1);
      final slice = CompactEpgSlice(
        entries: const [],
        generatedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        source: CompactEpgSliceSource.unavailable,
      );

      expect(slice.availabilityAt(now), CompactEpgAvailability.unavailable);
    });
  });
}
