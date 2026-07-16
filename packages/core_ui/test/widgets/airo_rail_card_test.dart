import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.byId(AppThemeId.airoTv).darkTheme,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('matches the design handoff card dimensions (172x104 thumbnail)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const AiroRailCard(name: 'Star Sports 1 HD', initials: 'SS1')),
    );

    final containerFinder = find.byType(Container).first;
    final container = tester.widget<Container>(containerFinder);
    expect((container.constraints ?? const BoxConstraints()).maxWidth, 172);

    final sizedBoxFinder = find
        .ancestor(
          of: find.text('SS1'),
          matching: find.byType(SizedBox),
        )
        .first;
    final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
    expect(sizedBox.height, 104);
  });

  testWidgets('shows LIVE badge only when isLive is true', (tester) async {
    await tester.pumpWidget(
      wrap(const AiroRailCard(name: 'Aaj Tak HD', isLive: true)),
    );
    expect(find.text('LIVE'), findsOneWidget);

    await tester.pumpWidget(
      wrap(const AiroRailCard(name: 'Star Plus HD', isLive: false)),
    );
    expect(find.text('LIVE'), findsNothing);
  });

  testWidgets('renders quality badge text when provided', (tester) async {
    await tester.pumpWidget(
      wrap(const AiroRailCard(name: 'ESPN HD', quality: 'HD')),
    );
    expect(find.text('HD'), findsOneWidget);
  });

  testWidgets('renders name and subtitle', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AiroRailCard(
          name: 'Star Sports 1 HD',
          subtitle: 'IND vs AUS · 2nd Test Day 3',
        ),
      ),
    );
    expect(find.text('Star Sports 1 HD'), findsOneWidget);
    expect(find.text('IND vs AUS · 2nd Test Day 3'), findsOneWidget);
  });
}
