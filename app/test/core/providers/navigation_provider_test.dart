import 'package:airo_app/core/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNavigationTab', () {
    test('uses the ten-tab information architecture order', () {
      expect(AppNavigationTab.values.map((tab) => tab.label), [
        'Coins',
        'Mind',
        'Beats',
        'Live',
        'Arena',
        'Quest',
        'Home',
        'Guide',
        'Favorites',
        'Settings',
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
        '/guide',
        '/favorites',
        '/settings',
      ]);
    });

    test('separates beats and live into distinct primary tabs', () {
      final rootLabels = AppNavigationTab.values.map((tab) => tab.label);
      final rootPaths = AppNavigationTab.values.map((tab) => tab.path);

      expect(AppNavigationTab.values.length, 10);
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
          tab == AppNavigationTab.live || tab == AppNavigationTab.home,
          reason: '${tab.label} IPTV mini player visibility',
        );
      }
    });

    test(
      'IPTV mini player is visible on both the Live and Home tabs',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          container
              .read(
                miniPlayerVisibilityProvider(AppNavigationTab.live.index),
              )
              .showIptvPlayer,
          isTrue,
        );
        expect(
          container
              .read(
                miniPlayerVisibilityProvider(AppNavigationTab.home.index),
              )
              .showIptvPlayer,
          isTrue,
        );
      },
    );

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

    test(
      'phone bottom nav exposes exactly 5 destinations matching the TV '
      'sidebar: Home, Live, Guide, Favorites, Settings',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final policy = container.read(appNavigationPolicyProvider);
        final phoneLayout = policy.layoutForWidth(390);
        final phoneTabs = phoneLayout.persistentTabs;

        expect(
          phoneTabs.map((t) => t.label).toList(),
          ['Home', 'Live', 'Guide', 'Favorites', 'Settings'],
        );
        expect(phoneLayout.overflowTabs, isEmpty);
        expect(phoneLayout.usesOverflow, isFalse);
      },
    );

    test(
      'wide layouts show a curated 8-tab set: the original six domains '
      'plus Guide and Favorites, excluding the placeholder Home tab',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final policy = container.read(appNavigationPolicyProvider);
        final wideLayout = policy.layoutForWidth(900);

        expect(policy.compactWidthBreakpoint, 600);
        expect(wideLayout.persistentTabs.map((t) => t.label).toList(), [
          'Coins',
          'Mind',
          'Beats',
          'Live',
          'Arena',
          'Quest',
          'Guide',
          'Favorites',
        ]);
        // Home is a phone-only placeholder for the unified browse entry
        // point; Mind already serves that role on wide layouts, so Home
        // must not appear here (it would read as a confusing duplicate).
        expect(wideLayout.persistentTabs, isNot(contains(AppNavigationTab.home)));
        // Settings has never had a persistent nav slot; it stays reachable
        // via the profile menu regardless of screen width.
        expect(
          wideLayout.persistentTabs,
          isNot(contains(AppNavigationTab.settings)),
        );
        expect(wideLayout.overflowTabs, isEmpty);
        expect(wideLayout.usesOverflow, isFalse);
      },
    );

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
      expect(appShellHeaderModeForLocation('/guide'), AppShellHeaderMode.shell);
      expect(
        appShellHeaderModeForLocation('/favorites'),
        AppShellHeaderMode.shell,
      );
    });

    test('switches custom and nested routes to route-owned headers', () {
      expect(appShellHeaderModeForLocation('/music'), AppShellHeaderMode.route);
      expect(appShellHeaderModeForLocation('/iptv'), AppShellHeaderMode.route);
      // Home (unified-browse Task 6) renders the same IPTVScreen as Live and
      // owns its own AppBar too, so shell chrome must stay hidden here.
      expect(appShellHeaderModeForLocation('/home'), AppShellHeaderMode.route);
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
      // SettingsHubScreen owns its own Scaffold + AppBar (see
      // settings_hub_screen.dart) so shell chrome must stay hidden here.
      expect(
        appShellHeaderModeForLocation('/settings'),
        AppShellHeaderMode.route,
      );
    });
  });
}
