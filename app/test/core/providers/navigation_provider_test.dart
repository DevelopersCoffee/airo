import 'package:airo_app/core/providers/navigation_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNavigationTab', () {
    test('uses the six-tab information architecture order', () {
      expect(
        AppNavigationTab.values.map((tab) => tab.label),
        ['Coins', 'Mind', 'Beats', 'Stream', 'Arena', 'Quest'],
      );
    });

    test('uses stable root paths for each tab', () {
      expect(
        AppNavigationTab.values.map((tab) => tab.path),
        ['/money', '/agent', '/beats', '/stream', '/games', '/quest'],
      );
    });
  });
}
