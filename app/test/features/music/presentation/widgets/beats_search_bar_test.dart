import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airo_app/features/music/presentation/widgets/beats_search_bar.dart';
import 'package:airo_app/features/music/application/providers/beats_provider.dart';
import 'package:airo_app/features/music/data/repositories/mock_beats_repository.dart';

void main() {
  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        beatsRepositoryProvider.overrideWithValue(MockBeatsRepository()),
      ],
      child: const MaterialApp(home: Scaffold(body: BeatsSearchBar())),
    );
  }

  group('BeatsSearchBar', () {
    testWidgets('renders search text field', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows search hint text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Search or paste YouTube URL...'), findsOneWidget);
    });

    testWidgets('shows search icon', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('can enter search text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test query');
      await tester.pump();

      expect(find.text('test query'), findsOneWidget);
    });

    testWidgets('shows clear button when text is entered', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button clears text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Text should be cleared
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });
  });
}
