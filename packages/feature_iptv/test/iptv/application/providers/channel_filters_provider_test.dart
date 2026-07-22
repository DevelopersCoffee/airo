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

  test('playlist country and language values backfill missing enrichment', () {
    final dimensions = channelFilterDimensions(
      channels: channels,
      metadataByChannelId: const {},
    );

    expect(dimensions.categories, {'News', 'Sports'});
    expect(dimensions.countries, {'IN'});
    expect(dimensions.languages, {'en'});
  });

  test(
    'category dimensions and matching deduplicate case and spacing variants',
    () {
      const duplicateCategories = [
        IPTVChannel(
          id: 'news-title',
          name: 'News title case',
          streamUrl: 'https://example.test/news-title',
          group: 'News',
        ),
        IPTVChannel(
          id: 'news-spaced',
          name: 'News spaced',
          streamUrl: 'https://example.test/news-spaced',
          group: ' news ',
        ),
        IPTVChannel(
          id: 'news-upper',
          name: 'News upper',
          streamUrl: 'https://example.test/news-upper',
          group: 'NEWS',
        ),
        IPTVChannel(
          id: 'sports',
          name: 'Sports',
          streamUrl: 'https://example.test/sports',
          group: 'Sports',
        ),
      ];

      expect(
        channelFilterDimensions(
          channels: duplicateCategories,
          metadataByChannelId: const {},
        ).categories,
        {'News', 'Sports'},
      );
      expect(
        applyChannelFilters(
          channels: duplicateCategories,
          filters: const ChannelFilters(category: 'News'),
          metadataByChannelId: const {},
        ).map((channel) => channel.id),
        ['news-title', 'news-spaced', 'news-upper'],
      );
    },
  );

  test('category dimensions split semicolon-separated playlist groups', () {
    const mixedCategories = [
      IPTVChannel(
        id: 'movie-news',
        name: 'Movie News',
        streamUrl: 'https://example.test/movie-news',
        group: 'Movies; News ; movies',
      ),
      IPTVChannel(
        id: 'sports',
        name: 'Sports',
        streamUrl: 'https://example.test/sports',
        group: 'Sports, General',
      ),
    ];

    expect(
      channelFilterDimensions(
        channels: mixedCategories,
        metadataByChannelId: const {},
      ).categories,
      {'Movies', 'News', 'Sports', 'General'},
    );
    expect(categoryDisplayLabel('Movies; News ; movies'), 'Movies, News');
    expect(
      applyChannelFilters(
        channels: mixedCategories,
        filters: const ChannelFilters(category: 'News'),
        metadataByChannelId: const {},
      ).map((channel) => channel.id),
      ['movie-news'],
    );
  });

  test('country limits language dimensions before a language is selected', () {
    const mixed = [
      IPTVChannel(
        id: 'india',
        name: 'India English',
        streamUrl: 'https://example.test/india',
        country: 'IN',
        languages: ['en', 'hi'],
      ),
      IPTVChannel(
        id: 'italy',
        name: 'Italy Italian',
        streamUrl: 'https://example.test/italy',
        country: 'IT',
        languages: ['it'],
      ),
    ];

    final dimensions = channelFilterDimensions(
      channels: mixed,
      metadataByChannelId: const {},
      country: 'IT',
    );

    expect(dimensions.countries, {'IN', 'IT'});
    expect(dimensions.languages, {'it'});
  });

  test(
    'country and language filters use playlist values without enrichment',
    () {
      const mixed = [
        IPTVChannel(
          id: 'india',
          name: 'India English',
          streamUrl: 'https://example.test/india',
          country: 'IN',
          languages: ['en'],
        ),
        IPTVChannel(
          id: 'italy',
          name: 'Italy Italian',
          streamUrl: 'https://example.test/italy',
          country: 'IT',
          languages: ['it'],
        ),
      ];

      expect(
        applyChannelFilters(
          channels: mixed,
          filters: const ChannelFilters(country: 'IT', language: 'it'),
          metadataByChannelId: const {},
        ).map((channel) => channel.id),
        ['italy'],
      );
    },
  );

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

  test('browser snapshot cache reuses derived list for unchanged inputs', () {
    final cache = ChannelBrowserSnapshotCache();

    final first = cache.resolve(
      channels: channels,
      metadataByChannelId: metadata,
      filters: const ChannelFilters(category: 'News'),
      sort: const ChannelSort(),
    );
    final second = cache.resolve(
      channels: channels,
      metadataByChannelId: metadata,
      filters: const ChannelFilters(category: 'News'),
      sort: const ChannelSort(),
    );
    final changed = cache.resolve(
      channels: channels,
      metadataByChannelId: metadata,
      filters: const ChannelFilters(category: 'Sports'),
      sort: const ChannelSort(),
    );

    expect(identical(first, second), isTrue);
    expect(identical(first, changed), isFalse);
    expect(first.visibleChannels.map((channel) => channel.id), [
      'alpha',
      'gamma',
    ]);
    expect(changed.visibleChannels.map((channel) => channel.id), ['beta']);
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

  test('country prompt is complete when country already exists', () async {
    SharedPreferences.setMockInitialValues({
      channelFilterCountryStorageKey: 'IN',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await Future<void>.delayed(Duration.zero);

    expect(
      container
          .read(channelCountryPromptProvider)
          .maybeWhen(data: (value) => value, orElse: () => null),
      isTrue,
    );
  });

  test('country prompt completion persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(first.dispose);

    await first.read(channelCountryPromptProvider.notifier).markCompleted();

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(
      restarted
          .read(channelCountryPromptProvider)
          .maybeWhen(data: (value) => value, orElse: () => null),
      isTrue,
    );
    expect(prefs.getBool(channelCountryPromptCompletedStorageKey), isTrue);
  });

  test('changing country clears a previously selected language', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(channelFiltersProvider.notifier).setLanguage('en');
    container.read(channelFiltersProvider.notifier).setCountry('IT');

    expect(
      container.read(channelFiltersProvider),
      const ChannelFilters(country: 'IT'),
    );
  });

  test('country labels use complete country names for common IPTV codes', () {
    expect(countryDisplayLabel('IN'), '🇮🇳 India');
    expect(countryDisplayLabel('AE'), '🇦🇪 United Arab Emirates');
    expect(countryDisplayLabel('KR'), '🇰🇷 South Korea');
    expect(countryDisplayLabel('ZA'), '🇿🇦 South Africa');
    expect(countryDisplayLabel('gb'), '🇬🇧 United Kingdom');
  });
}
