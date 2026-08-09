import 'dart:io';

import 'package:airo_app/features/settings/presentation/widgets/sibling_app_card.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  testWidgets('tapping a published app opens its platform store URL', (
    tester,
  ) async {
    Uri? launched;
    final app = SiblingApp(
      id: ShellId.tv,
      name: 'Airo TV',
      pitch: 'Live TV built for the big screen.',
      iconAsset:
          'packages/core_product_shell/assets/sibling_icons/airo_mark.png',
      androidStoreUrl: Uri.parse(
        'https://play.google.com/store/apps/details?id=com.airo.tv',
      ),
      iosStoreUrl: Uri.parse('https://apps.apple.com/app/com.airo.tv'),
      isPublishedAndroid: true,
      isPublishedIos: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SiblingAppCard(
            app: app,
            launchUrlCallback:
                (uri, {mode = LaunchMode.platformDefault}) async {
                  launched = uri;
                  return true;
                },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Airo TV'));
    await tester.pumpAndSettle();

    final expected = Platform.isIOS ? app.iosStoreUrl : app.androidStoreUrl;
    expect(launched, expected);
  });

  testWidgets('renders "Coming soon" and does not launch when unpublished', (
    tester,
  ) async {
    var launchCalled = false;
    final app = SiblingApp(
      id: ShellId.coins,
      name: 'Airo Coins',
      pitch: 'Track and manage your finances.',
      iconAsset:
          'packages/core_product_shell/assets/sibling_icons/airo_mark.png',
      androidStoreUrl: Uri.parse(
        'https://play.google.com/store/apps/details?id=com.airo.coins',
      ),
      iosStoreUrl: Uri.parse('https://apps.apple.com/app/com.airo.coins'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SiblingAppCard(
            app: app,
            launchUrlCallback:
                (uri, {mode = LaunchMode.platformDefault}) async {
                  launchCalled = true;
                  return true;
                },
          ),
        ),
      ),
    );

    expect(find.text('Coming soon'), findsOneWidget);

    await tester.tap(find.text('Airo Coins'));
    await tester.pumpAndSettle();

    expect(launchCalled, isFalse);
  });
}
