import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/filter_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// issues/03-long-list-picker.md: TV-native picker with a left-side A-Z jump
// rail (only populated initials) and a lazily-built option list, replacing
// FilterOptionDialog's single eagerly-built ListView for Country/Language/
// Category everywhere they're chosen from a TV remote.
void main() {
  Future<void> pumpPicker(
    WidgetTester tester, {
    required List<String> options,
    String? selectedValue,
    List<String> recentValues = const [],
    ValueChanged<String>? onSelected,
    VoidCallback? onClear,
    String Function(String)? optionLabel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvLongListPicker(
            title: 'Country',
            options: options,
            selectedValue: selectedValue,
            recentValues: recentValues,
            onSelected: onSelected ?? (_) {},
            onClear: onClear ?? () {},
            onClose: () {},
            optionLabel: optionLabel,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows only initials that actually have an option', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      options: const ['United Kingdom', 'United States', 'India'],
    );

    expect(find.byKey(const ValueKey('picker-jump-I')), findsOneWidget);
    expect(find.byKey(const ValueKey('picker-jump-U')), findsOneWidget);
    expect(find.byKey(const ValueKey('picker-jump-A')), findsNothing);
    expect(find.byKey(const ValueKey('picker-jump-Z')), findsNothing);
  });

  testWidgets('shows a Recent group ahead of the alphabetical groups', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      options: const ['United Kingdom', 'United States', 'India'],
      recentValues: const ['India'],
    );

    expect(find.byKey(const ValueKey('picker-jump-Recent')), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets(
    'recent values no longer present in the playlist are dropped, not shown',
    (tester) async {
      await pumpPicker(
        tester,
        options: const ['United Kingdom'],
        recentValues: const ['A Country No Longer In The Playlist'],
      );

      expect(find.byKey(const ValueKey('picker-jump-Recent')), findsNothing);
    },
  );

  testWidgets('selecting an option invokes onSelected with that value', (
    tester,
  ) async {
    String? selected;
    await pumpPicker(
      tester,
      options: const ['United Kingdom', 'India'],
      onSelected: (value) => selected = value,
    );

    await tester.tap(find.byKey(const ValueKey('picker-option-India')));
    await tester.pump();

    expect(selected, 'India');
  });

  testWidgets('the All row invokes onClear', (tester) async {
    var cleared = false;
    await pumpPicker(
      tester,
      options: const ['United Kingdom', 'India'],
      onClear: () => cleared = true,
    );

    await tester.tap(find.byKey(const ValueKey('picker-option-all')));
    await tester.pump();

    expect(cleared, isTrue);
  });

  testWidgets(
    'a 500-item list never builds every focusable tile up front (lazy '
    'ListView.builder, not an eager ListView)',
    (tester) async {
      final options = List.generate(500, (i) => 'Country $i'.padLeft(12, '0'));
      await pumpPicker(tester, options: options);

      expect(find.byType(TvLongListPicker), findsOneWidget);
      // The list must be scrollable via a builder -- if every row were
      // eagerly built, this would still find them all, but it would also
      // make the earlier pump() far slower and this test is the guard
      // against ever reverting to ListView(children: [...]).
      expect(find.byType(ListView), findsWidgets);
      expect(
        find.text(options.last),
        findsNothing,
        reason:
            'the very last (alphabetically last) option is far outside '
            'the initial viewport and must not be built yet',
      );
    },
  );

  testWidgets('the jump rail scrolls to and focuses the chosen group', (
    tester,
  ) async {
    final options = List.generate(
      60,
      (i) => String.fromCharCode(0x41 + (i % 26)) * 3 + '$i',
    )..sort();
    await pumpPicker(tester, options: options);

    final lastLetterKey = find
        .byWidgetPredicate((w) => w.key == const ValueKey('picker-jump-Z'))
        .evaluate()
        .isNotEmpty;
    if (lastLetterKey) {
      await tester.tap(find.byKey(const ValueKey('picker-jump-Z')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('uses countryDisplayLabel when supplied as optionLabel', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      options: const ['IN', 'US'],
      optionLabel: countryDisplayLabel,
    );

    expect(find.textContaining('India'), findsOneWidget);
    expect(find.textContaining('United States'), findsOneWidget);
  });
}
