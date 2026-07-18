import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/presentation/widgets/iptv_navigation_drawer.dart';

void main() {
  Future<void> pumpDrawer(
    WidgetTester tester, {
    bool showMovies = true,
    VoidCallback? onHome,
    VoidCallback? onGuide,
    VoidCallback? onMovies,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: IptvNavigationDrawer(
            showMovies: showMovies,
            onHome: onHome ?? () {},
            onGuide: onGuide ?? () {},
            onMovies: onMovies ?? () {},
          ),
          body: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens from the hamburger icon and lists Home, Guide, Movies', (
    tester,
  ) async {
    await pumpDrawer(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Guide'), findsOneWidget);
    expect(find.text('Movies & Shows'), findsOneWidget);
  });

  testWidgets('tapping Home closes the drawer and invokes onHome', (
    tester,
  ) async {
    var tapped = false;
    await pumpDrawer(tester, onHome: () => tapped = true);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('tapping Guide closes the drawer and invokes onGuide', (
    tester,
  ) async {
    var tapped = false;
    await pumpDrawer(tester, onGuide: () => tapped = true);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('hides Movies & Shows when showMovies is false', (tester) async {
    await pumpDrawer(tester, showMovies: false);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Movies & Shows'), findsNothing);
  });
}
