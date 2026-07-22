import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channels = [
    IPTVChannel(
      id: 'alpha',
      name: 'Alpha News',
      streamUrl: 'https://example.test/alpha',
      group: 'News',
    ),
    IPTVChannel(
      id: 'beta',
      name: 'Beta Sport',
      streamUrl: 'https://example.test/beta',
      group: 'Sports',
    ),
    IPTVChannel(
      id: 'gamma',
      name: 'Gamma News',
      streamUrl: 'https://example.test/gamma',
      group: 'News',
    ),
  ];

  const metadata = {
    'alpha': ChannelBrowseMetadata(country: 'IN', language: 'hi'),
    'beta': ChannelBrowseMetadata(country: 'US', language: 'en'),
    'gamma': ChannelBrowseMetadata(country: 'IN', language: 'en'),
  };

  test('combined filters retain only channels matching every value', () {
    final filters = ChannelFilters(
      category: 'News',
      country: 'IN',
      language: 'en',
    );

    expect(
      applyChannelFilters(
        channels: channels,
        filters: filters,
        metadataByChannelId: metadata,
      ).map((channel) => channel.id),
      ['gamma'],
    );
  });

  test('metadata dimensions exclude values that have no verified metadata', () {
    final dimensions = channelFilterDimensions(
      channels: channels,
      metadataByChannelId: const {},
    );

    expect(dimensions.categories, {'News', 'Sports'});
    expect(dimensions.countries, isEmpty);
    expect(dimensions.languages, isEmpty);
  });

  test('sort reverses and composes with a filter', () {
    const filters = ChannelFilters(category: 'News');
    final filtered = applyChannelFilters(
      channels: channels,
      filters: filters,
      metadataByChannelId: metadata,
    );

    expect(
      sortChannels(
        channels: filtered,
        metadataByChannelId: metadata,
        sort: const ChannelSort(
          column: ChannelSortColumn.name,
          ascending: false,
        ),
      ).map((channel) => channel.id),
      ['gamma', 'alpha'],
    );
  });

  test('filter state survives a fresh provider container', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final overrides = [sharedPreferencesProvider.overrideWithValue(prefs)];
    final first = ProviderContainer(overrides: overrides);
    addTearDown(first.dispose);

    first.read(channelFiltersProvider.notifier).setCountry('IN');
    first.read(channelFiltersProvider.notifier).setLanguage('hi');
    await Future<void>.delayed(Duration.zero);

    final restarted = ProviderContainer(overrides: overrides);
    addTearDown(restarted.dispose);

    expect(
      restarted.read(channelFiltersProvider),
      const ChannelFilters(country: 'IN', language: 'hi'),
    );
  });
}
