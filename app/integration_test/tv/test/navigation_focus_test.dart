import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'helpers/tv_test_harness.dart';
import 'helpers/tv_screen_robot.dart';
import 'helpers/focus_assertions.dart';
import 'package:core_data/core_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Focus navigation and back-button behavior', (WidgetTester tester) async {
    final harness = TvTestHarness(tester, deviceClass: DeviceClass.tvLow);
    await harness.setUp();

    final robot = TvScreenRobot(tester);
    final focus = FocusAssertions(tester);

    // Iterate through each top‑level route and verify focus traversal.
    const routes = ['Live', 'Guide', 'VOD', 'Favorites', 'Settings'];
    for (final route in routes) {
      await robot.navigateTo(route);
      await focus.assertNoFocusTrap();
      await focus.assertFocusVisible();
    }

    // Test Back button navigation from a deep screen (e.g., channel details).
    await robot.navigateToLive();
    await robot.selectChannel('Vevo Pop');
    await tester.pumpAndSettle();
    // Press Back – should return to Live screen.
    await robot.pressKey(LogicalKeyboardKey.goBack);
    await tester.pumpAndSettle();
    expect(find.text('Live'), findsOneWidget, reason: 'Back button did not return to Live screen');

    // Test on‑screen keyboard invocation on a search field.
    await robot.navigateTo('Guide');
    // Find a search field – assuming it has semantics label 'Search'.
    final searchFinder = find.bySemanticsLabel('Search');
    expect(searchFinder, findsOneWidget, reason: 'Search field missing');
    await tester.tap(searchFinder);
    await tester.pumpAndSettle();
    // Verify that the platform keyboard appears – we mock via focus check.
    await focus.assertKeyboardVisible();

    await harness.tearDown();
  }, tags: <String>{'tv_integration'});
}
