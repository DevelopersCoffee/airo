import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('standard variant renders name, subtitle, quality badge',
      (tester) async {
    await tester.pumpWidget(_host(const MediaCard(
      name: 'Star Sports 1 HD',
      subtitle: 'IND vs AUS',
      quality: 'HD',
    )));
    expect(find.text('Star Sports 1 HD'), findsOneWidget);
    expect(find.text('IND vs AUS'), findsOneWidget);
    expect(find.text('HD'), findsOneWidget);
  });

  testWidgets('live variant shows LIVE badge', (tester) async {
    await tester.pumpWidget(_host(const MediaCard(
      name: 'Aaj Tak',
      variant: MediaCardVariant.live,
    )));
    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('hero variant is wider than standard', (tester) async {
    await tester.pumpWidget(_host(const Row(children: [
      MediaCard(name: 'A', variant: MediaCardVariant.hero),
    ])));
    final size = tester.getSize(find.byType(MediaCard));
    expect(size.width, greaterThan(172));
  });

  testWidgets('compact variant is narrower than standard', (tester) async {
    await tester.pumpWidget(_host(const Row(children: [
      MediaCard(name: 'A', variant: MediaCardVariant.compact),
    ])));
    final size = tester.getSize(find.byType(MediaCard));
    expect(size.width, lessThan(172));
  });
}
