import 'package:airo_app/core/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNavigationTab', () {
    test('groups music and TV into one media tab', () {
      expect(AppNavigationTab.values.map((tab) => tab.label), [
        'Coins',
        'Mind',
        'Media',
        'Arena',
        'Quest',
      ]);
    });

    test('uses stable root paths for each tab', () {
      expect(AppNavigationTab.values.map((tab) => tab.path), [
        '/money',
        '/agent',
        '/media',
        '/games',
        '/quest',
      ]);
    });

    test('hides mini players on the grouped media tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final tab in AppNavigationTab.values) {
        final visibility = container.read(
          miniPlayerVisibilityProvider(tab.index),
        );

        expect(
          visibility.showMusicPlayer,
          isFalse,
          reason: '${tab.label} music mini player visibility',
        );
        expect(
          visibility.showIptvPlayer,
          isFalse,
          reason: '${tab.label} IPTV mini player visibility',
        );
      }
    });
  });
}
