import 'package:airo_app/features/bill_split/presentation/screens/itemized_split_screen.dart';
import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:airo_app/features/coins/application/providers/settlement_providers.dart';
import 'package:airo_app/features/coins/application/providers/split_providers.dart';
import 'package:airo_app/features/coins/presentation/screens/group_detail_itemized_bill.dart';
import 'package:core_app_shell/core_app_shell.dart';
import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/fake_group_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = 'group_itemized';

  testWidgets('shows snackbar when the group has no members', (tester) async {
    final repository = FakeGroupRepository(membersByGroup: {groupId: const []});

    await tester.pumpWidget(
      _host(
        groupId: groupId,
        repository: repository,
        onOpen: (context, ref) =>
            openGroupItemizedBillSplit(context, ref, groupId),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open itemized split'));
    await tester.pumpAndSettle();

    expect(find.text('Add group members before splitting'), findsOneWidget);
    expect(find.byType(ItemizedSplitScreen), findsNothing);
  });

  testWidgets('shows snackbar when the saved split has no amounts', (
    tester,
  ) async {
    final repository = FakeGroupRepository(
      membersByGroup: {
        groupId: [_member(groupId, 'uday', 'Uday')],
      },
    );

    await tester.pumpWidget(
      _host(
        groupId: groupId,
        repository: repository,
        onOpen: (context, ref) =>
            openGroupItemizedBillSplit(context, ref, groupId),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open itemized split'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemizedSplitScreen), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop(
      const ItemizedSplitResult(
        totalAmount: 0,
        description: 'Empty receipt',
        summary: {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No split amounts found in this bill'), findsOneWidget);
    expect(repository.lastAddedExpense, isNull);
  });

  testWidgets('persists itemized split including fee adjustments', (
    tester,
  ) async {
    final repository = FakeGroupRepository(
      membersByGroup: {
        groupId: [
          _member(groupId, 'uday', 'Uday'),
          _member(groupId, 'rahul', 'Rahul'),
        ],
      },
    );

    await tester.pumpWidget(
      _host(
        groupId: groupId,
        repository: repository,
        onOpen: (context, ref) =>
            openGroupItemizedBillSplit(context, ref, groupId),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open itemized split'));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop(
      ItemizedSplitResult(
        totalAmount: 100,
        description: 'Team lunch',
        summary: const {'uday': 6000, 'rahul': 4000},
        itemizedDetails: const [
          ItemizedSplitItem(
            name: 'Burger & Fries!!!',
            pricePaise: 5000,
            participantIds: {'uday', 'rahul'},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Itemized bill saved to Coins'), findsOneWidget);
    final saved = repository.lastAddedExpense;
    expect(saved, isNotNull);
    expect(saved!.description, 'Team lunch');
    expect(saved.splitType, SplitType.itemized);
    expect(saved.totalAmountCents, 10000);
    expect(saved.splits, hasLength(2));
    expect(
      saved.splits.map((split) => split.amountCents),
      unorderedEquals([6000, 4000]),
    );
  });

  testWidgets('surfaces repository errors when saving the split fails', (
    tester,
  ) async {
    final repository = FakeGroupRepository(
      membersByGroup: {
        groupId: [_member(groupId, 'uday', 'Uday')],
      },
      addExpenseResult: (_) async => (data: null, error: 'db locked'),
    );

    await tester.pumpWidget(
      _host(
        groupId: groupId,
        repository: repository,
        onOpen: (context, ref) =>
            openGroupItemizedBillSplit(context, ref, groupId),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open itemized split'));
    await tester.pumpAndSettle();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pop(
          const ItemizedSplitResult(
            totalAmount: 10,
            description: 'Snack',
            summary: {'uday': 1000},
            itemizedDetails: [
              ItemizedSplitItem(
                name: 'Chips',
                pricePaise: 1000,
                participantIds: {'uday'},
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('db locked'), findsOneWidget);
  });

  testWidgets('shows snackbar when member lookup fails', (tester) async {
    final repository = FakeGroupRepository(
      getMembersResult: (_) async => (data: null, error: 'offline'),
    );

    await tester.pumpWidget(
      _host(
        groupId: groupId,
        repository: repository,
        onOpen: (context, ref) =>
            openGroupItemizedBillSplit(context, ref, groupId),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open itemized split'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to open bill upload'), findsOneWidget);
  });
}

Widget _host({
  required String groupId,
  required FakeGroupRepository repository,
  required Future<void> Function(BuildContext context, WidgetRef ref) onOpen,
}) {
  return ProviderScope(
    overrides: [
      groupRepositoryProvider.overrideWithValue(repository),
      addSplitUseCaseProvider.overrideWithValue(
        AddSplitUseCase(repository, SplitCalculatorImpl()),
      ),
      groupBalanceSummaryProvider(groupId).overrideWith(
        (ref) async => BalanceSummary(
          groupId: groupId,
          netBalances: const {},
          debts: const [],
          simplifiedDebts: const [],
          totalExpensesCents: 0,
          totalSettlementsCents: 0,
          calculatedAt: DateTime(2026, 10, 6),
        ),
      ),
      currencyFormatterProvider.overrideWithValue(
        CurrencyFormatter.fromCode('USD'),
      ),
    ],
    child: MaterialApp(home: _Opener(onOpen: onOpen)),
  );
}

GroupMember _member(String groupId, String userId, String name) {
  return GroupMember(
    id: 'member_$userId',
    groupId: groupId,
    userId: userId,
    displayName: name,
    joinedAt: DateTime(2026, 10, 6),
  );
}

class _Opener extends ConsumerWidget {
  const _Opener({required this.onOpen});

  final Future<void> Function(BuildContext context, WidgetRef ref) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async => onOpen(context, ref),
          child: const Text('Open itemized split'),
        ),
      ),
    );
  }
}
