import 'package:airo_app/core/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNavigationTab', () {
    test('uses the six-tab information architecture order', () {
      expect(AppNavigationTab.values.map((tab) => tab.label), [
        'Coins',
        'Brain',
        'Beats',
        'Stream',
        'Arena',
        'Quest',
      ]);
    });

    test('uses stable root paths for each tab', () {
      expect(AppNavigationTab.values.map((tab) => tab.path), [
        '/money',
        '/agent',
        '/beats',
        '/stream',
        '/games',
        '/quest',
      ]);
    });

    test('limits persistent mini players to media tabs', () {
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
  });
}
