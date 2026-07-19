import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  testWidgets('renders one AiroRail per RailResult with MediaCards',
      (tester) async {
    const ch = IPTVChannel(id: 'x', name: 'Star Sports', streamUrl: 'u');
    final rails = [
      const RailResult(
        definition: RailDefinition(
          id: 'top-india', title: 'Top India', query: RailQuery(), priority: 0,
        ),
        channels: [ch],
      ),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [railsProvider.overrideWith((ref) async => rails)],
      child: const MaterialApp(home: BrowseScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Top India'), findsOneWidget);
    expect(find.text('Star Sports'), findsOneWidget);
  });

  testWidgets('shows loading indicator while rails build', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        railsProvider.overrideWith((ref) => Future.any([])),
      ],
      child: const MaterialApp(home: BrowseScreen()),
    ));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
