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

  testWidgets('phone profile shows debug pause body when policy allows ads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AikaPauseNativeAdCard(
            debugBodyOverride: SizedBox(key: Key('pause-ad-body')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.bySemanticsLabel('Advertisement'), findsOneWidget);
  });

  testWidgets('pause card hides when leanback policy blocks ads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AikaPauseNativeAdCard(isLeanback: true)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.bySemanticsLabel('Advertisement'), findsNothing);
    expect(manager.shouldShowAd(isLeanback: true, isCasting: false), isFalse);
  });

  testWidgets('pause card dismiss records an ad impression', (tester) async {
    expect(manager.policy.lastImpressionAt, isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AikaPauseNativeAdCard(
            debugBodyOverride: SizedBox(key: Key('pause-ad-body')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Hide ad'));
    await tester.pump();

    expect(find.bySemanticsLabel('Advertisement'), findsNothing);
    expect(manager.policy.lastImpressionAt, isNotNull);
  });

  testWidgets('browse card skips load when casting policy blocks ads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AikaBrowseNativeAdCard(isCasting: true)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.bySemanticsLabel('Advertisement'), findsNothing);
    expect(manager.shouldShowAd(isLeanback: false, isCasting: true), isFalse);
  });

  testWidgets('browse card dismiss records an ad impression', (tester) async {
    expect(manager.policy.lastImpressionAt, isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AikaBrowseNativeAdCard(
            debugBodyOverride: SizedBox(key: Key('browse-ad-body')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Hide ad'));
    await tester.pump();

    expect(find.byKey(const Key('browse-ad-body')), findsNothing);
    expect(manager.policy.lastImpressionAt, isNotNull);
  });
}
