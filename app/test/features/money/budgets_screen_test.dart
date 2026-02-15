import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:airo_app/core/database/app_database.dart';
import 'package:airo_app/features/money/application/providers/money_provider.dart';
import 'package:airo_app/features/money/data/repositories/local_budgets_repository.dart';
import 'package:airo_app/features/money/presentation/screens/budgets_screen.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        budgetsRepositoryProvider.overrideWith(
          (ref) => LocalBudgetsRepository(db),
        ),
      ],
    );
  });

  tearDown(() async {
    // Dispose Riverpod container first to close all streams
    container.dispose();
    // Small delay to allow microtasks to complete
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // Then close the database
    await db.close();
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
      expect(find.text('\$0.00 / \$500.00'), findsOneWidget);
    });

    testWidgets('shows budget progress correctly', (tester) async {
      // Pre-populate a budget
      final repo = LocalBudgetsRepository(db);
      await repo.create(tag: 'Entertainment', limitCents: 10000);
      await repo.deductFromBudget('Entertainment', -5000);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows exceeded budget warning', (tester) async {
      // Pre-populate an exceeded budget
      final repo = LocalBudgetsRepository(db);
      await repo.create(tag: 'Shopping', limitCents: 5000);
      await repo.deductFromBudget('Shopping', -7500);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Shopping'), findsOneWidget);
      expect(find.textContaining('Budget exceeded'), findsOneWidget);
    });

    testWidgets('can delete a budget', (tester) async {
      // Pre-populate a budget
      final repo = LocalBudgetsRepository(db);
      await repo.create(tag: 'Healthcare', limitCents: 20000);

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
