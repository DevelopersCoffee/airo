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
}
