import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:airo_app/features/money/application/providers/money_provider.dart';
import 'package:airo_app/features/money/presentation/screens/budgets_screen.dart';

void main() {
  late ProviderContainer container;
  late FakeBudgetsRepository budgetsRepo;

  setUp(() async {
    budgetsRepo = FakeBudgetsRepository();
    await budgetsRepo.clear();
    container = ProviderContainer(
      overrides: [budgetsRepositoryProvider.overrideWithValue(budgetsRepo)],
    );
  });

  tearDown(() async {
    container.dispose();
  });

  Widget createTestWidget() {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: BudgetsScreen()),
    );
  }

  group('BudgetsScreen', () {
    testWidgets('shows empty state when no budgets', (tester) async {
      await tester.pumpWidget(createTestWidget());
      // Use pump with duration instead of pumpAndSettle to avoid
      // hanging on Drift stream subscriptions that emit continuously
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No budgets yet'), findsOneWidget);
      expect(
        find.text('Create budgets to track your spending'),
        findsOneWidget,
      );
      expect(find.text('Create Budget'), findsOneWidget);
    });

    testWidgets('shows FAB to add budget', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('opens create dialog when FAB tapped', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create Budget'), findsWidgets);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Monthly Limit'), findsOneWidget);
    });

    testWidgets('can create a budget', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Enter limit amount
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monthly Limit'),
        '500',
      );

      // Tap create button
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      // Should show the created budget
      expect(find.text('Food & Drink'), findsOneWidget);
      expect(find.text('₹0.00 / ₹500.00'), findsOneWidget);
    });

    testWidgets('shows budget progress correctly', (tester) async {
      // Pre-populate a budget
      final result = await budgetsRepo.create(
        tag: 'Entertainment',
        limitCents: 10000,
      );
      await budgetsRepo.updateUsage(result.getOrNull()!.id, 5000);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows exceeded budget warning', (tester) async {
      // Pre-populate an exceeded budget
      final result = await budgetsRepo.create(
        tag: 'Shopping',
        limitCents: 5000,
      );
      await budgetsRepo.updateUsage(result.getOrNull()!.id, 7500);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Shopping'), findsOneWidget);
      expect(find.textContaining('Budget exceeded'), findsOneWidget);
    });

    testWidgets('can delete a budget', (tester) async {
      // Pre-populate a budget
      await budgetsRepo.create(tag: 'Healthcare', limitCents: 20000);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Open menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm delete
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.text('No budgets yet'), findsOneWidget);
    });
  });
}
