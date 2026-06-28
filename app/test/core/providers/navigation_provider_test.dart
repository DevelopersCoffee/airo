import 'package:airo_app/core/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNavigationTab', () {
    test('uses the six-tab information architecture order', () {
      expect(AppNavigationTab.values.map((tab) => tab.label), [
        'Coins',
        'Mind',
        'Beats',
        'Stream',
        'Arena',
        'Quest',
      ]);
    });

    test('defaults to the finance dashboard for daily-use speed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(currentNavigationTabProvider),
        AppNavigationTab.coins.index,
      );
    });

    test('uses stable root paths for each tab', () {
      expect(AppNavigationTab.values.map((tab) => tab.path), [
        '/money',
        '/mind',
        '/music',
        '/iptv',
        '/games',
        '/quest',
      ]);
    });

    test('separates beats and stream into distinct primary tabs', () {
      final rootLabels = AppNavigationTab.values.map((tab) => tab.label);
      final rootPaths = AppNavigationTab.values.map((tab) => tab.path);

      expect(AppNavigationTab.values.length, 6);
      expect(rootLabels, containsAll(['Beats', 'Stream']));
      expect(rootPaths, containsAll(['/music', '/iptv']));
    });

    test('shows each persistent mini player only on its owning media tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final tab in AppNavigationTab.values) {
        final visibility = container.read(
          miniPlayerVisibilityProvider(tab.index),
        );

        expect(
          visibility.showMusicPlayer,
          tab == AppNavigationTab.beats,
          reason: '${tab.label} music mini player visibility',
        );
        expect(
          visibility.showIptvPlayer,
          tab == AppNavigationTab.stream,
          reason: '${tab.label} IPTV mini player visibility',
        );
      }
    });

    test('centralizes shell chrome actions for compact and wide layouts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final chromeConfig = container.read(appNavigationChromeConfigProvider);

      expect(chromeConfig.enabledActions, const [
        AppShellAction.notifications,
        AppShellAction.profileMenu,
      ]);
      expect(chromeConfig.compactWidthBreakpoint, 600);
    });

    test('keeps shell-owned headers only on routes without local app bars', () {
      expect(appShellHeaderModeForLocation('/money'), AppShellHeaderMode.shell);
      expect(appShellHeaderModeForLocation('/mind'), AppShellHeaderMode.shell);
      expect(
        appShellHeaderModeForLocation('/mind/chat'),
        AppShellHeaderMode.shell,
      );
      expect(
        appShellHeaderModeForLocation('/mind/models'),
        AppShellHeaderMode.shell,
      );
      expect(appShellHeaderModeForLocation('/games'), AppShellHeaderMode.shell);
    });

    test('switches custom and nested routes to route-owned headers', () {
      expect(appShellHeaderModeForLocation('/music'), AppShellHeaderMode.route);
      expect(appShellHeaderModeForLocation('/iptv'), AppShellHeaderMode.route);
      expect(appShellHeaderModeForLocation('/quest'), AppShellHeaderMode.route);
      expect(
        appShellHeaderModeForLocation('/quest/new'),
        AppShellHeaderMode.route,
      );
      expect(
        appShellHeaderModeForLocation('/money/dashboard'),
        AppShellHeaderMode.route,
      );
      expect(
        appShellHeaderModeForLocation('/money/groups/alpha'),
        AppShellHeaderMode.route,
      );
      expect(
        appShellHeaderModeForLocation('/mind/profile'),
        AppShellHeaderMode.route,
      );
      expect(
        appShellHeaderModeForLocation('/mind/notifications'),
        AppShellHeaderMode.route,
      );
    });
  });
}
