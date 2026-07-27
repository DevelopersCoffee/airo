import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders one AiroRail per RailResult with MediaCards', (
    tester,
  ) async {
    const ch = IPTVChannel(id: 'x', name: 'Star Sports', streamUrl: 'u');
    final rails = [
      const RailResult(
        definition: RailDefinition(
          id: 'top-india',
          title: 'Channels in India',
          query: RailQuery(),
          priority: 0,
        ),
        channels: [ch],
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [railsProvider.overrideWith((ref) async => rails)],
        child: const MaterialApp(home: BrowseScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Channels in India'), findsOneWidget);
    expect(find.text('Star Sports'), findsOneWidget);
  });

  testWidgets('rail cards are keyboard focusable and selectable', (
    tester,
  ) async {
    var selected = false;
    final rails = [
      const RailResult(
        definition: RailDefinition(
          id: 'regional-IN',
          title: 'Channels in India',
          query: RailQuery(),
          priority: 0,
        ),
        channels: [IPTVChannel(id: 'x', name: 'DD National', streamUrl: 'u')],
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [railsProvider.overrideWith((ref) async => rails)],
        child: MaterialApp(
          home: BrowseScreen(onChannelSelected: (_) => selected = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, isTrue);
  });

  testWidgets('shows loading indicator while rails build', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [railsProvider.overrideWith((ref) => Future.any([]))],
        child: const MaterialApp(home: BrowseScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
