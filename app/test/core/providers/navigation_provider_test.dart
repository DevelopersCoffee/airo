import 'package:airo_app/core/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNavigationTab', () {
    test('uses the seven-tab information architecture order', () {
      expect(AppNavigationTab.values.map((tab) => tab.label), [
        'Coins',
        'Assistant',
        'Beats',
        'Live',
        'Arena',
        'Quest',
        'Home',
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
        '/home',
      ]);
    });

    test('separates beats and live into distinct primary tabs', () {
      final rootLabels = AppNavigationTab.values.map((tab) => tab.label);
      final rootPaths = AppNavigationTab.values.map((tab) => tab.path);

      expect(AppNavigationTab.values.length, 7);
      expect(rootLabels, containsAll(['Beats', 'Live']));
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
        // Home renders the same real browse/player flow as Live (Task 6
        // mirrors the source design's Home==Live routing), so the IPTV mini
        // player must show on both tabs.
        expect(
          visibility.showIptvPlayer,
          tab == AppNavigationTab.live,
          reason: '${tab.label} IPTV mini player visibility',
        );
      }
    });

    test('IPTV mini player is visible only on the Live tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container
            .read(miniPlayerVisibilityProvider(AppNavigationTab.live.index))
            .showIptvPlayer,
        isTrue,
      );
      expect(
        container
            .read(miniPlayerVisibilityProvider(AppNavigationTab.home.index))
            .showIptvPlayer,
        isFalse,
      );
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

    test('phone navigation preserves Airo domains and overflows the rest', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final policy = container.read(appNavigationPolicyProvider);
      final phoneLayout = policy.layoutForWidth(390);
      final phoneTabs = phoneLayout.persistentTabs;

      expect(phoneTabs.map((t) => t.label).toList(), [
        'Coins',
        'Assistant',
        'Beats',
        'Live',
      ]);
      expect(phoneLayout.overflowTabs.map((t) => t.label).toList(), [
        'Arena',
        'Quest',
        'Home',
      ]);
      expect(phoneLayout.usesOverflow, isTrue);
      expect({
        ...phoneTabs,
        ...phoneLayout.overflowTabs,
      }, containsAll(AppNavigationTab.values));
    });

    test('wide layouts show only the six core super-app domains', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final policy = container.read(appNavigationPolicyProvider);
      final wideLayout = policy.layoutForWidth(900);

      expect(policy.compactWidthBreakpoint, 600);
      expect(wideLayout.persistentTabs.map((t) => t.label).toList(), [
        'Coins',
        'Assistant',
        'Beats',
        'Live',
        'Arena',
        'Quest',
      ]);
      // Home remains reachable from the persistent shell identity, so wide
      // navigation can prioritize the six daily-use destinations.
      expect(wideLayout.persistentTabs, isNot(contains(AppNavigationTab.home)));
      expect(wideLayout.overflowTabs, isEmpty);
      expect(wideLayout.usesOverflow, isFalse);
    });

    test('keeps shell-owned headers only on routes without local app bars', () {
      expect(appShellHeaderModeForLocation('/money'), AppShellHeaderMode.shell);
      expect(
        appShellHeaderModeForLocation('/assistant'),
        AppShellHeaderMode.shell,
      );
      expect(
        appShellHeaderModeForLocation('/assistant/chat'),
        AppShellHeaderMode.shell,
      );
      expect(
        appShellHeaderModeForLocation('/assistant/models'),
        AppShellHeaderMode.shell,
      );
      expect(
        appShellHeaderModeForLocation('/mind'),
        AppShellHeaderMode.shell,
      );
      expect(
        appShellHeaderModeForLocation('/mind/chat'),
        AppShellHeaderMode.shell,
      );
      expect(
        appShellHeaderModeForLocation('/mind/models'),
        AppShellHeaderMode.shell,
      );
      expect(appShellHeaderModeForLocation('/games'), AppShellHeaderMode.shell);
      expect(appShellHeaderModeForLocation('/home'), AppShellHeaderMode.shell);
      expect(appShellHeaderModeForLocation('/guide'), AppShellHeaderMode.shell);
      expect(
        appShellHeaderModeForLocation('/favorites'),
        AppShellHeaderMode.shell,
      );
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
        AppShellHeaderMode.shell,
      );
      expect(
        appShellHeaderModeForLocation('/money/groups/alpha'),
        AppShellHeaderMode.route,
      );
      expect(
        appShellHeaderModeForLocation('/assistant/profile'),
        AppShellHeaderMode.route,
      );
      expect(
        appShellHeaderModeForLocation('/assistant/notifications'),
        AppShellHeaderMode.route,
      );
      // Canonical SSOT path (post `/assistant` -> `/mind` migration): the
      // legacy `/assistant` literal above must not be the only prefix that
      // routes pushed-nested Mind screens (profile, notifications, ...) to
      // route-owned chrome, or the shell AppBar/NavigationBar stay stuck on
      // whatever tab was active before the push.
      expect(
        appShellHeaderModeForLocation('/mind/profile'),
        AppShellHeaderMode.route,
      );
      expect(
        appShellHeaderModeForLocation('/mind/notifications'),
        AppShellHeaderMode.route,
      );
      // SettingsHubScreen owns its own Scaffold + AppBar (see
      // settings_hub_screen.dart) so shell chrome must stay hidden here.
      expect(
        appShellHeaderModeForLocation('/settings'),
        AppShellHeaderMode.route,
      );
    });
  });
}
