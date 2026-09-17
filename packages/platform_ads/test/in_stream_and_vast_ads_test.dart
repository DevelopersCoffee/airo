import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_ads/platform_ads.dart';

void main() {
  group('AiroPauseAdOverlay', () {
    testWidgets('renders child and shows overlay when paused', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiroPauseAdOverlay(
              isPaused: true,
              child: Container(key: const Key('video_player')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('video_player')), findsOneWidget);
    });

    testWidgets('omits overlay when playing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiroPauseAdOverlay(
              isPaused: false,
              child: Container(key: const Key('video_player')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('video_player')), findsOneWidget);
    });
  });

  group('AiroLowerThirdOverlayAd', () {
    testWidgets('renders lower third overlay banner and dismisses on close', (
      tester,
    ) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                AiroLowerThirdOverlayAd(
                  adTitle: 'Live Match Sponsor',
                  adDescription: 'Special 20% discount on merchandise',
                  displayDuration: const Duration(seconds: 5),
                  onAdDismissed: () => dismissed = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Live Match Sponsor'), findsOneWidget);
      expect(find.text('Special 20% discount on merchandise'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });
  });

  group('AiroVastAdTag & Parser', () {
    test('constructs Google Ad Manager VAST tag URL', () {
      final tag = AiroVastAdTag.googleAdManager(
        adUnitPath: '/1234567/sports_live',
        descriptionUrl: 'https://developerscoffee.com',
      );

      expect(tag.tagUrl, contains('pubads.g.doubleclick.net'));
      expect(tag.tagUrl, contains('iu=%2F1234567%2Fsports_live'));
      expect(tag.tagUrl, contains('output=vast'));
    });

    test('parses VAST XML response', () {
      const xml = '''
      <VAST version="4.0">
        <Ad id="1">
          <InLine>
            <AdSystem>Google GAM</AdSystem>
            <AdTitle>Aika Stream Championship</AdTitle>
            <Impression>https://example.com/impression/1</Impression>
            <MediaFile type="video/mp4">https://example.com/ads/video.mp4</MediaFile>
          </InLine>
        </Ad>
      </VAST>
      ''';

      final tag = AiroVastTagParser.parseXml(
        tagUrl: 'https://example.com/vast.xml',
        xmlContent: xml,
      );

      expect(tag.adSystem, equals('Google GAM'));
      expect(tag.adTitle, equals('Aika Stream Championship'));
      expect(tag.impressionUrls, contains('https://example.com/impression/1'));
      expect(tag.mediaFileUrl, equals('https://example.com/ads/video.mp4'));
    });
  });
}
