import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/presentation/widgets/iptv_navigation_drawer.dart';

void main() {
  Future<void> pumpDrawer(
    WidgetTester tester, {
    bool showMovies = true,
    VoidCallback? onHome,
    VoidCallback? onGuide,
    VoidCallback? onGuideSource,
    VoidCallback? onMovies,
    VoidCallback? onFavorites,
    VoidCallback? onPlayLocalFileOnTv,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: IptvNavigationDrawer(
            showMovies: showMovies,
            onHome: onHome ?? () {},
            onGuide: onGuide ?? () {},
            onGuideSource: onGuideSource ?? () {},
            onMovies: onMovies ?? () {},
            onFavorites: onFavorites ?? () {},
            onPlayLocalFileOnTv: onPlayLocalFileOnTv,
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

  testWidgets('opens from the hamburger icon and lists IPTV destinations', (
    tester,
  ) async {
    await pumpDrawer(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Guide'), findsOneWidget);
    expect(find.text('Guide Source'), findsOneWidget);
    expect(find.text('Movies & Shows'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
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

  testWidgets(
    'tapping Guide Source closes the drawer and invokes onGuideSource',
    (tester) async {
      var tapped = false;
      await pumpDrawer(tester, onGuideSource: () => tapped = true);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guide Source'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    },
  );

  testWidgets('tapping Favorites closes the drawer and invokes onFavorites', (
    tester,
  ) async {
    var tapped = false;
    await pumpDrawer(tester, onFavorites: () => tapped = true);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(find.text('Favorites'), findsNothing);
  });

  testWidgets('hides Movies & Shows when showMovies is false', (tester) async {
    await pumpDrawer(tester, showMovies: false);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Movies & Shows'), findsNothing);
  });

  testWidgets('hides Play file on TV when onPlayLocalFileOnTv is null', (
    tester,
  ) async {
    await pumpDrawer(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Play file on TV (debug)'), findsNothing);
  });

  testWidgets(
    'tapping Play file on TV closes the drawer and invokes the callback',
    (tester) async {
      var tapped = false;
      await pumpDrawer(tester, onPlayLocalFileOnTv: () => tapped = true);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Play file on TV (debug)'), findsOneWidget);

      await tester.tap(find.text('Play file on TV (debug)'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(find.text('Play file on TV (debug)'), findsNothing);
    },
  );
}
