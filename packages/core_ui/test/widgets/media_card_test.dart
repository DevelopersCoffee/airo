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

  testWidgets('variant dimensions are pinned', (tester) async {
    Future<(double, double)> dimensionsOf(MediaCardVariant variant) async {
      await tester.pumpWidget(_host(Row(children: [
        MediaCard(name: 'A', variant: variant),
      ])));
      final width = tester.getSize(find.byType(MediaCard)).width;
      final sizedBoxFinder = find
          .ancestor(of: find.text('A'), matching: find.byType(SizedBox))
          .first;
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
      return (width, sizedBox.height!);
    }

    final (standardWidth, standardHeight) = await dimensionsOf(MediaCardVariant.standard);
    expect(standardWidth, 172);
    expect(standardHeight, 104);

    final (liveWidth, liveHeight) = await dimensionsOf(MediaCardVariant.live);
    expect(liveWidth, 172);
    expect(liveHeight, 104);

    final (compactWidth, compactHeight) = await dimensionsOf(MediaCardVariant.compact);
    expect(compactWidth, 140);
    expect(compactHeight, 84);

    final (heroWidth, heroHeight) = await dimensionsOf(MediaCardVariant.hero);
    expect(heroWidth, 320);
    expect(heroHeight, 180);
  });

  testWidgets('isLive shows LIVE badge on any variant', (tester) async {
    await tester.pumpWidget(_host(const MediaCard(name: 'A', isLive: true)));
    expect(find.text('LIVE'), findsOneWidget);
  });

  test('railHeightFor derives from each variant\'s thumbnail height', () {
    expect(MediaCard.railHeightFor(MediaCardVariant.compact), 84 + 64);
    expect(MediaCard.railHeightFor(MediaCardVariant.standard), 104 + 64);
    expect(MediaCard.railHeightFor(MediaCardVariant.live), 104 + 64);
    expect(MediaCard.railHeightFor(MediaCardVariant.hero), 180 + 64);
  });
}
