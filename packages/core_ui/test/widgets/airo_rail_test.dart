import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders title, subtitle, and all children horizontally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.byId(AppThemeId.airoTv).darkTheme,
        home: Scaffold(
          body: AiroRail(
            title: 'Top 50 India',
            subtitle: 'Ranked by viewers in your region',
            children: const [
              AiroRailCard(name: 'Star Sports 1 HD'),
              AiroRailCard(name: 'Sony Six HD'),
              AiroRailCard(name: 'ESPN HD'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Top 50 India'), findsOneWidget);
    expect(find.text('Ranked by viewers in your region'), findsOneWidget);
    expect(find.byType(AiroRailCard), findsNWidgets(3));
    expect(find.byType(ListView), findsOneWidget);

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.scrollDirection, Axis.horizontal);
  });

  Future<double> _railBandHeight(
    WidgetTester tester, {
    double? railHeight,
    MediaCardVariant? cardVariant,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.byId(AppThemeId.airoTv).darkTheme,
        home: Scaffold(
          body: AiroRail(
            title: 'Rail',
            railHeight: railHeight,
            cardVariant: cardVariant,
            // A bare SizedBox rather than a real card: this helper only
            // measures the rail's own band height, and a real card would
            // overflow a deliberately-undersized override in the test below.
            children: const [SizedBox.shrink()],
          ),
        ),
      ),
    );
    return tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .firstWhere((box) => box.child is ListView)
        .height!;
  }

  testWidgets(
    'falls back to 156 when neither railHeight nor cardVariant is set',
    (tester) async {
      expect(await _railBandHeight(tester), 156);
    },
  );

  testWidgets('derives height from cardVariant via MediaCard.railHeightFor', (
    tester,
  ) async {
    expect(
      await _railBandHeight(tester, cardVariant: MediaCardVariant.compact),
      MediaCard.railHeightFor(MediaCardVariant.compact),
    );
    expect(
      await _railBandHeight(tester, cardVariant: MediaCardVariant.hero),
      MediaCard.railHeightFor(MediaCardVariant.hero),
    );
  });

  testWidgets('explicit railHeight overrides cardVariant', (tester) async {
    expect(
      await _railBandHeight(
        tester,
        railHeight: 60,
        cardVariant: MediaCardVariant.compact,
      ),
      60,
    );
  });
}
