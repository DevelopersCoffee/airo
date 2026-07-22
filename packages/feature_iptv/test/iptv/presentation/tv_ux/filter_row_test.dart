import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/filter_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'active filter fills its chip and missing dimensions stay hidden',
    (tester) async {
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

      expect(find.text('IN'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
      expect(find.byKey(const ValueKey('filter-chip-country')), findsOneWidget);
    },
  );
}
