import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AiroTheme.byId(AppThemeId.airoTv).darkTheme,
    home: Scaffold(body: Center(child: child)),
  );

  group('DraftConfirmCard', () {
    testWidgets('renders title and field labels', (tester) async {
      await tester.pumpWidget(
        wrap(
          DraftConfirmCard(
            title: 'Split expense',
            fields: [
              DraftField(label: 'Amount', value: const Text('₹420')),
              DraftField(label: 'Category', value: const Text('Food')),
            ],
            onConfirm: () {},
            onReject: () {},
          ),
        ),
      );

      expect(find.text('Split expense'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('₹420'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets(
      'shows an AI-drafted badge only for aiExtracted fields',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            DraftConfirmCard(
              title: 'Split expense',
              fields: [
                DraftField(label: 'Amount', value: const Text('₹420')),
                DraftField(
                  label: 'Category',
                  value: const Text('Food'),
                  provenance: DraftFieldProvenance.aiExtracted,
                ),
              ],
              onConfirm: () {},
              onReject: () {},
            ),
          ),
        );

        expect(find.text('AI-drafted'), findsOneWidget);
      },
    );

    testWidgets('confirm never fires without an explicit tap', (
      tester,
    ) async {
      var confirmed = false;
      await tester.pumpWidget(
        wrap(
          DraftConfirmCard(
            title: 'Split expense',
            fields: const [],
            onConfirm: () => confirmed = true,
            onReject: () {},
          ),
        ),
      );

      // Widget rendered, fully settled -- nothing auto-commits.
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);

      await tester.tap(find.byKey(const ValueKey('draft_confirm_card.confirm')));
      expect(confirmed, isTrue);
    });

    testWidgets('reject fires only on explicit tap', (tester) async {
      var rejected = false;
      await tester.pumpWidget(
        wrap(
          DraftConfirmCard(
            title: 'Split expense',
            fields: const [],
            onConfirm: () {},
            onReject: () => rejected = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('draft_confirm_card.reject')));
      expect(rejected, isTrue);
    });

    testWidgets('redo action is hidden when onRedo is null', (tester) async {
      await tester.pumpWidget(
        wrap(
          DraftConfirmCard(
            title: 'Split expense',
            fields: const [],
            onConfirm: () {},
            onReject: () {},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('draft_confirm_card.redo')),
        findsNothing,
      );
    });

    testWidgets('redo action fires when provided', (tester) async {
      var redone = false;
      await tester.pumpWidget(
        wrap(
          DraftConfirmCard(
            title: 'Split expense',
            fields: const [],
            onConfirm: () {},
            onReject: () {},
            onRedo: () => redone = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('draft_confirm_card.redo')));
      expect(redone, isTrue);
    });

    testWidgets('edit action fires only for fields with onEdit', (
      tester,
    ) async {
      var edited = false;
      await tester.pumpWidget(
        wrap(
          DraftConfirmCard(
            title: 'Split expense',
            fields: [
              DraftField(
                label: 'Amount',
                value: const Text('₹420'),
                onEdit: () => edited = true,
              ),
              DraftField(label: 'Category', value: const Text('Food')),
            ],
            onConfirm: () {},
            onReject: () {},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('draft_confirm_card.edit.Amount')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('draft_confirm_card.edit.Category')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('draft_confirm_card.edit.Amount')),
      );
      expect(edited, isTrue);
    });
  });

  group('DraftConfirmLoadingCard', () {
    testWidgets('renders the required message, never a bare spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const DraftConfirmLoadingCard(message: 'Reading locally... a few seconds')),
      );

      expect(find.text('Reading locally... a few seconds'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exposes the message as a live-region announcement', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const DraftConfirmLoadingCard(message: 'Reading locally')),
      );

      final semantics = tester.getSemantics(
        find.byType(DraftConfirmLoadingCard),
      );
      expect(semantics.label, contains('Reading locally'));
    });
  });
}
