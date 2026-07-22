import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/application/providers/hotbar_channels_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/saved_filters_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  test('saved filters de-duplicate an identical combination', () async {
    final value = await container();
    addTearDown(value.dispose);
    const filters = ChannelFilters(category: 'News', country: 'IN');

    value.read(savedFiltersProvider.notifier).save(filters);
    value.read(savedFiltersProvider.notifier).save(filters);
    await Future<void>.delayed(Duration.zero);

    expect(value.read(savedFiltersProvider), [filters]);
  });

  test('hotbar entry stores a channel and its filter combination', () async {
    final value = await container();
    addTearDown(value.dispose);
    const filters = ChannelFilters(category: 'Sports', language: 'en');

    value
        .read(hotbarChannelsProvider.notifier)
        .pin(channelId: 'channel-1', filters: filters);
    await Future<void>.delayed(Duration.zero);

    expect(value.read(hotbarChannelsProvider), [
      const HotbarChannelEntry(channelId: 'channel-1', filters: filters),
    ]);
  });

  test('saved state survives a fresh provider container', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final overrides = [sharedPreferencesProvider.overrideWithValue(prefs)];
    final first = ProviderContainer(overrides: overrides);
    addTearDown(first.dispose);
    const filters = ChannelFilters(country: 'US');

    first.read(savedFiltersProvider.notifier).save(filters);
    first
        .read(hotbarChannelsProvider.notifier)
        .pin(channelId: 'channel-2', filters: filters);
    await Future<void>.delayed(Duration.zero);

    final restarted = ProviderContainer(overrides: overrides);
    addTearDown(restarted.dispose);

    expect(restarted.read(savedFiltersProvider), [filters]);
    expect(restarted.read(hotbarChannelsProvider), [
      const HotbarChannelEntry(channelId: 'channel-2', filters: filters),
    ]);
  });
}
