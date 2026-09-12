import 'package:feature_iptv/presentation/tv_ux/sections/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('renders Home, Search, My Aika destinations', (tester) async {
    await tester.pumpWidget(
      wrap(IptvBottomNavBar(onHome: () {}, onSearch: () {}, onMyAika: () {})),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('My Aika'), findsOneWidget);
  });

  testWidgets('tapping each destination calls its callback', (tester) async {
    var home = false, search = false, myAika = false;
    await tester.pumpWidget(
      wrap(
        IptvBottomNavBar(
          onHome: () => home = true,
          onSearch: () => search = true,
          onMyAika: () => myAika = true,
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.tap(find.text('Search'));
    await tester.tap(find.text('My Aika'));
    expect(home, isTrue);
    expect(search, isTrue);
    expect(myAika, isTrue);
  });
}
