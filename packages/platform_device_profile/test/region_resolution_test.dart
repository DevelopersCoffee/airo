import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

final class _Cache implements RegionNetworkCache {
  RegionNetworkCacheEntry? value;

  @override
  Future<RegionNetworkCacheEntry?> read() async => value;

  @override
  Future<void> write(RegionNetworkCacheEntry entry) async => value = entry;
}

void main() {
  final now = DateTime.utc(2026, 7, 27);

  test('SIM answer short-circuits locale and network', () async {
    var localeCalls = 0;
    var networkCalls = 0;
    final result = await RegionResolver(
      simCountry: () async => 'in',
      localeCountry: () async {
        localeCalls++;
        return 'GB';
      },
      networkCountry: () async {
        networkCalls++;
        return 'US';
      },
      allowNetworkLookup: true,
      clock: () => now,
    ).resolve();

    expect(result.countryCode, 'IN');
    expect(result.source, RegionResolutionSource.sim);
    expect(localeCalls, 0);
    expect(networkCalls, 0);
  });

  test('locale answer prevents network lookup', () async {
    var networkCalls = 0;
    final result = await RegionResolver(
      simCountry: () async => null,
      localeCountry: () async => 'gb',
      networkCountry: () async {
        networkCalls++;
        return 'US';
      },
      allowNetworkLookup: true,
      clock: () => now,
    ).resolve();

    expect(result.countryCode, 'GB');
    expect(result.source, RegionResolutionSource.locale);
    expect(networkCalls, 0);
  });

  test('fresh 30-day cache avoids network', () async {
    final cache = _Cache()
      ..value = RegionNetworkCacheEntry(
        countryCode: 'US',
        resolvedAt: now.subtract(const Duration(days: 30)),
      );
    var networkCalls = 0;
    final result = await RegionResolver(
      simCountry: () async => null,
      localeCountry: () async => null,
      networkCache: cache,
      networkCountry: () async {
        networkCalls++;
        return 'CA';
      },
      allowNetworkLookup: true,
      clock: () => now,
    ).resolve();

    expect(result.countryCode, 'US');
    expect(result.source, RegionResolutionSource.cachedNetwork);
    expect(networkCalls, 0);
  });

  test('network is never called without explicit opt-in', () async {
    var networkCalls = 0;
    final result = await RegionResolver(
      simCountry: () async => null,
      localeCountry: () async => null,
      networkCountry: () async {
        networkCalls++;
        return 'US';
      },
      clock: () => now,
    ).resolve();

    expect(result.isAvailable, isFalse);
    expect(networkCalls, 0);
  });
}
