import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/iptv_org_api_providers.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/filter_row.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/search_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:platform_iptv_org_api/platform_iptv_org_api.dart';

void main() {
  testWidgets('search is first and country uses human-readable labels', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(channelFiltersProvider.notifier).setCountry('IN');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilterRow(
              dimensions: ChannelFilterDimensions(
                categories: {'News'},
                countries: {'IN'},
                languages: {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('🇮🇳 India'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.byKey(const ValueKey('filter-chip-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-chip-country')), findsOneWidget);

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('filter-chip-search'))).dx,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('filter-chip-country'))).dx,
      ),
    );
  });

  testWidgets('wide filter row keeps category and country labels readable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1080,
              child: FilterRow(
                dimensions: ChannelFilterDimensions(
                  categories: {'General'},
                  countries: {'US', 'IN'},
                  languages: {'en'},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('typed taxonomy replaces built-in country and language labels', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvOrgCountryByCodeProvider.overrideWithValue(const {
          'IN': IptvOrgCountry(
            name: 'Bharat',
            code: 'IN',
            languages: ['hin'],
            flag: '🇮🇳',
          ),
        }),
        iptvOrgLanguageByCodeProvider.overrideWithValue(const {
          'hin': IptvOrgLanguage(name: 'Hindi', code: 'hin'),
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(channelFiltersProvider.notifier)
      ..setCountry('IN')
      ..setLanguage('hin');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilterRow(
              dimensions: ChannelFilterDimensions(
                categories: {},
                countries: {'IN'},
                languages: {'hin'},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('🇮🇳 Bharat'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);
  });

  testWidgets('search chip updates and clears channel filter search text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilterRow(
              dimensions: ChannelFilterDimensions(
                categories: {},
                countries: {},
                languages: {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('filter-chip-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('search-overlay-field')),
      'news',
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(container.read(channelFiltersProvider).search, 'news');
    expect(find.text('news'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('filter-chip-search-clear')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('filter-chip-search-clear')));
    await tester.pumpAndSettle();

    expect(container.read(channelFiltersProvider).search, '');
    expect(find.text('Search'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('filter-chip-search-clear')),
      findsNothing,
    );
  });

  testWidgets('clear search keeps the other active channel filters', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(channelFiltersProvider.notifier)
      ..setCategory('News')
      ..setSearch('local');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilterRow(
              dimensions: ChannelFilterDimensions(
                categories: {'News', 'Sports'},
                countries: {},
                languages: {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Clear search'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(
      container.read(channelFiltersProvider),
      const ChannelFilters(category: 'News'),
    );
  });

  testWidgets('clear search stays visible on a Pixel 9-width layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container
        .read(channelFiltersProvider.notifier)
        .setSearch('a deliberately long channel search');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilterRow(
              dimensions: ChannelFilterDimensions(
                categories: {'News'},
                countries: {'IN'},
                languages: {'hin'},
              ),
            ),
          ),
        ),
      ),
    );

    final clearFinder = find.byKey(const ValueKey('filter-chip-search-clear'));
    expect(clearFinder, findsOneWidget);
    expect(tester.getSize(clearFinder).width, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('search overlay clears typed text without closing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilterRow(
              dimensions: ChannelFilterDimensions(
                categories: {},
                countries: {},
                languages: {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('filter-chip-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('search-overlay-field')),
      'news',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('search-overlay-clear')));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('search-overlay-field')),
    );
    expect(field.controller?.text, isEmpty);
    expect(find.byKey(const ValueKey('search-overlay-clear')), findsNothing);
    expect(find.byType(SearchOverlay), findsOneWidget);
  });

  testWidgets('language choices use human-readable labels', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilterRow(
              dimensions: ChannelFilterDimensions(
                categories: {},
                countries: {'IN', 'IT'},
                languages: {'en', 'it'},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('filter-chip-language')));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Italian'), findsOneWidget);
  });

  testWidgets('all category clears only the category filter', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(channelFiltersProvider.notifier);
    notifier.setCountry('IN');
    notifier.setLanguage('en');
    notifier.setCategory('News');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilterRow(
              dimensions: ChannelFilterDimensions(
                categories: {'News', 'Sports'},
                countries: {'IN'},
                languages: {'en'},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('filter-chip-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Categories'));
    await tester.pumpAndSettle();

    expect(
      container.read(channelFiltersProvider),
      const ChannelFilters(country: 'IN', language: 'en'),
    );
  });

  testWidgets('all country preserves category and clears dependent language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(channelFiltersProvider.notifier);
    notifier.setCategory('News');
    notifier.setCountry('IN');
    notifier.setLanguage('en');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FilterRow(
              dimensions: ChannelFilterDimensions(
                categories: {'News'},
                countries: {'IN', 'US'},
                languages: {'en'},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('filter-chip-country')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Countries'));
    await tester.pumpAndSettle();

    expect(
      container.read(channelFiltersProvider),
      const ChannelFilters(category: 'News'),
    );
  });

  testWidgets(
    'selecting a language records it as Recent for the next picker open',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: FilterRow(
                dimensions: ChannelFilterDimensions(
                  categories: {},
                  countries: {},
                  languages: {'en', 'hi', 'it'},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('filter-chip-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hindi'));
      await tester.pumpAndSettle();

      expect(container.read(recentFilterValuesProvider).languages, ['hi']);

      await tester.tap(find.byKey(const ValueKey('filter-chip-language')));
      await tester.pumpAndSettle();

      expect(find.text('Recent'), findsOneWidget);
      expect(find.byKey(const ValueKey('picker-option-hi')), findsOneWidget);
    },
  );
}
