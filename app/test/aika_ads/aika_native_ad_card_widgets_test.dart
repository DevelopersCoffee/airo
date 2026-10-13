import 'package:airo_app/aika_ads/aika_ad_manager_binding.dart';
import 'package:airo_app/aika_ads/aika_ads.dart';
import 'package:airo_app/aika_ads/aika_browse_native_ad_card.dart';
import 'package:airo_app/aika_ads/aika_pause_native_ad_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final manager = AikaAdManager.test(
      sdk: AikaAdSdk(initializeFn: () async => true),
    );
    await manager.initialize(formFactor: AiroDeviceFormFactor.mobile);
    bindAikaAdManagerForTests(manager);
  });

  tearDown(() {
    bindAikaAdManagerForTests(null);
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
  });

  testWidgets('pause card renders dismissible placeholder body in tests', (
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

    expect(find.bySemanticsLabel('Advertisement'), findsOneWidget);
    expect(find.byKey(const Key('pause-ad-body')), findsOneWidget);

    await tester.tap(find.byTooltip('Hide ad'));
    await tester.pump();

    expect(find.bySemanticsLabel('Advertisement'), findsNothing);
  });

  testWidgets('browse card skips load when casting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AikaBrowseNativeAdCard(isCasting: true)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.bySemanticsLabel('Advertisement'), findsNothing);
  });

  testWidgets('browse card renders and dismisses debug body', (tester) async {
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

    expect(find.byKey(const Key('browse-ad-body')), findsOneWidget);
    await tester.tap(find.byTooltip('Hide ad'));
    await tester.pump();

    expect(find.byKey(const Key('browse-ad-body')), findsNothing);
  });
}
