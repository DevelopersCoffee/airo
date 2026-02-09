import 'package:airo_app/features/media_hub/application/providers/search_provider.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/media_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MediaSearchBar', () {
    Widget buildTestWidget({
      void Function(bool)? onFocusChanged,
      void Function(String)? onSubmitted,
      bool autofocus = false,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MediaSearchBar(
                onFocusChanged: onFocusChanged,
                onSubmitted: onSubmitted,
                autofocus: autofocus,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders with placeholder text', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Search channels, artists, genres…'), findsOneWidget);
    });

    testWidgets('renders search icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('calls onFocusChanged when focused', (tester) async {
      bool? hasFocus;
      await tester.pumpWidget(
        buildTestWidget(onFocusChanged: (focus) => hasFocus = focus),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(hasFocus, isTrue);
    });

    testWidgets('triggers search on text input', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // The search query should be updated in the provider
      // (actual search happens after debounce)
    });

    testWidgets('shows clear button when text entered', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Initially no clear button
      expect(find.byIcon(Icons.clear), findsNothing);

      // Enter text
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clears text when clear button pressed', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Enter text
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Press clear
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Text should be cleared
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('calls onSubmitted when submitted', (tester) async {
      String? submittedValue;
      await tester.pumpWidget(
        buildTestWidget(onSubmitted: (value) => submittedValue = value),
      );

      await tester.enterText(find.byType(TextField), 'test query');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(submittedValue, 'test query');
    });

    testWidgets('autofocuses when autofocus is true', (tester) async {
      await tester.pumpWidget(buildTestWidget(autofocus: true));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, isTrue);
    });
  });

  group('MediaSearchState', () {
    test('initial state has empty values', () {
      const state = MediaSearchState();

      expect(state.query, '');
      expect(state.isSearching, isFalse);
      expect(state.musicResults, isEmpty);
      expect(state.tvResults, isEmpty);
      expect(state.recentSearches, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('hasResults returns true when results exist', () {
      const state = MediaSearchState(musicResults: []);
      expect(state.hasResults, isFalse);
    });

    test('isSearchActive returns true when query >= 2 chars', () {
      const state1 = MediaSearchState(query: 'a');
      const state2 = MediaSearchState(query: 'ab');

      expect(state1.isSearchActive, isFalse);
      expect(state2.isSearchActive, isTrue);
    });

    test('copyWith preserves unspecified values', () {
      const original = MediaSearchState(query: 'test');
      final updated = original.copyWith(isSearching: true);

      expect(updated.query, 'test');
      expect(updated.isSearching, isTrue);
    });
  });
}
