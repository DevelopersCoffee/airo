import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('siblingAppsFor', () {
    test('excludes the current shell from its own sibling list', () {
      final result = siblingAppsFor(ShellId.mobile);

      expect(result.any((app) => app.id == ShellId.mobile), isFalse);
    });

    test('returns the other three shipped apps for a known shell', () {
      final result = siblingAppsFor(ShellId.tv);

      expect(
        result.map((app) => app.id),
        containsAll(const [ShellId.mobile, ShellId.coins, ShellId.mind]),
      );
      expect(result, hasLength(3));
    });

    test('returns all shipped apps for a shell not in the registry', () {
      final result = siblingAppsFor(const ShellId('unregistered'));

      expect(result, hasLength(4));
    });
  });

  group('siblingApps', () {
    test('covers every shipped shell exactly once', () {
      final ids = siblingApps.map((app) => app.id).toSet();

      expect(ids, {ShellId.mobile, ShellId.tv, ShellId.coins, ShellId.mind});
      expect(siblingApps, hasLength(4));
    });
  });

  group('publishedSiblingAppsFor', () {
    test('is empty while every listing flag is still a placeholder', () {
      // Settings screens hide their "More Airo Apps" section when this is
      // empty, so a section of inert "Coming soon" cards is never rendered.
      // Flipping an isPublished* flag in the registry is the only change
      // needed to bring the section back.
      expect(publishedSiblingAppsFor(ShellId.tv), isEmpty);
      expect(publishedSiblingAppsFor(ShellId.mobile), isEmpty);
    });

    test('never includes the current shell', () {
      for (final shell in const [
        ShellId.mobile,
        ShellId.tv,
        ShellId.coins,
        ShellId.mind,
      ]) {
        expect(
          publishedSiblingAppsFor(shell).any((app) => app.id == shell),
          isFalse,
        );
      }
    });
  });

  group('SiblingApp.isPublishedAnywhere', () {
    SiblingApp appWith({required bool android, required bool ios}) =>
        SiblingApp(
          id: ShellId.coins,
          name: 'Airo Coins',
          pitch: 'pitch',
          iconAsset: 'asset.png',
          androidStoreUrl: Uri.parse('https://play.google.com/store'),
          iosStoreUrl: Uri.parse('https://apps.apple.com/app'),
          isPublishedAndroid: android,
          isPublishedIos: ios,
        );

    test('is false only when neither store listing is live', () {
      expect(appWith(android: false, ios: false).isPublishedAnywhere, isFalse);
      expect(appWith(android: true, ios: false).isPublishedAnywhere, isTrue);
      expect(appWith(android: false, ios: true).isPublishedAnywhere, isTrue);
    });
  });
}
