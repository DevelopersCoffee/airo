import 'package:feature_iptv/presentation/tv_ux/sections/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders Home, Browse, Fav, My Aika destinations', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        IptvBottomNavBar(
          selected: IptvPhoneNavDestination.home,
          onHome: () {},
          onBrowse: () {},
          onFavorites: () {},
          onMyAika: () {},
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Fav'), findsOneWidget);
    expect(find.text('My Aika'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('tapping each destination calls its callback', (tester) async {
    var home = false, browse = false, favorites = false, myAika = false;
    await tester.pumpWidget(
      wrap(
        IptvBottomNavBar(
          selected: IptvPhoneNavDestination.home,
          onHome: () => home = true,
          onBrowse: () => browse = true,
          onFavorites: () => favorites = true,
          onMyAika: () => myAika = true,
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.tap(find.text('Browse'));
    await tester.tap(find.text('Fav'));
    await tester.tap(find.text('My Aika'));
    expect(home, isTrue);
    expect(browse, isTrue);
    expect(favorites, isTrue);
    expect(myAika, isTrue);
  });
}
