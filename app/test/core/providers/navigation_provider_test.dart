import 'package:airo_app/core/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNavigationTab', () {
    test('uses the five-tab information architecture order', () {
      expect(AppNavigationTab.values.map((tab) => tab.label), [
        'Dashboard',
        'Assistant',
        'Entertainment',
        'Games',
        'Tasks',
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
        '/agent',
        '/live',
        '/games',
        '/quest',
      ]);
    });

    test('keeps music and tv inside the entertainment architecture', () {
      final rootLabels = AppNavigationTab.values.map((tab) => tab.label);
      final rootPaths = AppNavigationTab.values.map((tab) => tab.path);

      expect(AppNavigationTab.values.length, 5);
      expect(rootLabels, contains('Entertainment'));
      expect(rootLabels, isNot(contains('Music')));
      expect(rootLabels, isNot(contains('TV')));
      expect(rootPaths, contains('/live'));
      expect(rootPaths, isNot(contains('/beats')));
      expect(rootPaths, isNot(contains('/stream')));
    });

    test('hides persistent mini players on the owning media tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final tab in AppNavigationTab.values) {
        final visibility = container.read(
          miniPlayerVisibilityProvider(tab.index),
        );

        expect(
          visibility.showMusicPlayer,
          tab != AppNavigationTab.entertainment,
          reason: '${tab.label} music mini player visibility',
        );
        expect(
          visibility.showIptvPlayer,
          tab != AppNavigationTab.entertainment,
          reason: '${tab.label} IPTV mini player visibility',
        );
      }
    });
  });
}
