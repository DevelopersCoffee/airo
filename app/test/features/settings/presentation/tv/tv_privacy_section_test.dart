import 'package:airo_app/features/settings/application/aika_stream_local_data_deletion.dart';
import 'package:airo_app/features/settings/presentation/tv/tv_privacy_section.dart';
import 'package:core_data/core_data.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('privacy section offers delete local data', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        ],
        child: const MaterialApp(home: Scaffold(body: TvPrivacySection())),
      ),
    );
    await tester.pump();

    expect(find.text('Delete local data'), findsOneWidget);
  });

  testWidgets('cancelling delete local data does not run the deleter', (
    tester,
  ) async {
    var deleted = false;
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
          aikaStreamLocalDataDeleterProvider.overrideWithValue(() async {
            deleted = true;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: TvPrivacySection())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Delete local data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete local data?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
  });

  testWidgets('confirming delete local data runs the deleter', (tester) async {
    var deleted = false;
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
          aikaStreamLocalDataDeleterProvider.overrideWithValue(() async {
            deleted = true;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: TvPrivacySection())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Delete local data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.text('Local data deleted'), findsOneWidget);
  });
}
