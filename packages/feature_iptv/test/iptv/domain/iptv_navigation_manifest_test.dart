import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iptvNavigationDestinations', () {
    test('declares exactly Home, Guide, Movies/VOD, Favorites, Settings in '
        'order', () {
      expect(iptvNavigationDestinations.map((d) => d.id).toList(), const [
        IptvDestinationId.home,
        IptvDestinationId.guide,
        IptvDestinationId.vod,
        IptvDestinationId.favorites,
        IptvDestinationId.settings,
      ]);
    });

    test('mobile and TV share the same destination list (one manifest, two '
        'renderers)', () {
      // Neither shell filters this list today — both render every
      // destination (mobile additionally gates "vod"/"settings" via
      // separate widget-level flags, not via the manifest).
      for (final destination in iptvNavigationDestinations) {
        expect(destination.labelFor(ShellId.mobile), isNotEmpty);
        expect(destination.labelFor(ShellId.tv), isNotEmpty);
      }
    });

    test('preserves the pre-existing label drift between shells for VOD '
        '(mobile "Movies & Shows", TV "Movies")', () {
      final vod = iptvNavigationDestinations.firstWhere(
        (d) => d.id == IptvDestinationId.vod,
      );

      expect(vod.labelFor(ShellId.mobile), 'Movies & Shows');
      expect(vod.labelFor(ShellId.tv), 'Movies');
    });

    test('a destination with no override resolves the same label for any '
        'shell, including a hypothetical third shell', () {
      final home = iptvNavigationDestinations.firstWhere(
        (d) => d.id == IptvDestinationId.home,
      );

      expect(home.labelFor(ShellId.mobile), 'Home');
      expect(home.labelFor(ShellId.tv), 'Home');
      expect(home.labelFor(ShellId.coins), 'Home');
    });
  });
}
