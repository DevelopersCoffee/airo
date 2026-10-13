import 'package:airo_app/aika_ads/aika_ad_manager_binding.dart';
import 'package:airo_app/aika_ads/aika_ads.dart';
import 'package:airo_app/aika_ads/aika_ads_runtime.dart';
import 'package:airo_app/aika_ads/aika_browse_native_ad_card.dart';
import 'package:airo_app/aika_ads/aika_pause_native_ad_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AikaAdManager manager;

  setUp(() async {
    manager = AikaAdManager.test(
      sdk: AikaAdSdk(initializeFn: () async => true),
    );
    await manager.initialize(formFactor: AiroDeviceFormFactor.mobile);
    allowImmediateAikaPhoneAds(manager);
    bindAikaAdManagerForTests(manager);
  });

  tearDown(() {
    bindAikaAdManagerForTests(null);
  });

  testWidgets('pause card shows debug body when phone policy allows ads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AikaPauseNativeAdCard(
            debugBodyOverride: SizedBox(key: Key('pause-ad-body-allowed')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('pause-ad-body-allowed')), findsOneWidget);
  });

  testWidgets('pause card omits debug body when leanback policy blocks ads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AikaPauseNativeAdCard(
            isLeanback: true,
            debugBodyOverride: SizedBox(key: Key('pause-ad-body-leanback')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('pause-ad-body-leanback')), findsNothing);
  });

  testWidgets('pause card dismiss records an ad impression', (tester) async {
    expect(manager.policy.lastImpressionAt, isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AikaPauseNativeAdCard(
            debugBodyOverride: SizedBox(key: Key('pause-ad-body-dismiss')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Hide ad'));
    await tester.pump();

    expect(find.byKey(const Key('pause-ad-body-dismiss')), findsNothing);
    expect(manager.policy.lastImpressionAt, isNotNull);
  });

  testWidgets('browse card shows debug body when phone policy allows ads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AikaBrowseNativeAdCard(
            debugBodyOverride: SizedBox(key: Key('browse-ad-body-allowed')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('browse-ad-body-allowed')), findsOneWidget);
  });

  testWidgets('browse card omits debug body when casting policy blocks ads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AikaBrowseNativeAdCard(
            isCasting: true,
            debugBodyOverride: SizedBox(key: Key('browse-ad-body-casting')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('browse-ad-body-casting')), findsNothing);
  });

  testWidgets('browse card dismiss records an ad impression', (tester) async {
    expect(manager.policy.lastImpressionAt, isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AikaBrowseNativeAdCard(
            debugBodyOverride: SizedBox(key: Key('browse-ad-body-dismiss')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Hide ad'));
    await tester.pump();

    expect(find.byKey(const Key('browse-ad-body-dismiss')), findsNothing);
    expect(manager.policy.lastImpressionAt, isNotNull);
  });
}
