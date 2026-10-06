import 'package:core_app_shell/core_app_shell.dart';
import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:airo_app/features/coins/application/providers/coins_currency_provider.dart';
import 'package:airo_app/features/coins/application/providers/settlement_providers.dart';
import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:airo_app/features/coins/presentation/screens/add_split_expense_screen.dart';
import 'package:airo_app/features/coins/presentation/screens/group_detail_screen.dart';
import 'package:airo_app/features/coins/presentation/screens/group_detail_super_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_support/fake_group_repository.dart';

void main() {
  testWidgets('shows real simplified debts with member names and currency', (
    tester,
  ) async {
    const groupId = 'group_1';
    final group = Group(
      id: groupId,
      name: 'Goa Trip',
      defaultCurrencyCode: 'USD',
      creatorId: 'uday',
      createdAt: DateTime(2026, 5, 13),
    );
    final members = [
      GroupMember(
        id: 'member_1',
        groupId: groupId,
        userId: 'uday',
        displayName: 'Uday',
        joinedAt: DateTime(2026, 5, 13),
      ),
      GroupMember(
        id: 'member_2',
        groupId: groupId,
        userId: 'rahul',
        displayName: 'Rahul',
        joinedAt: DateTime(2026, 5, 13),
      ),
    ];
    final summary = BalanceSummary(
      groupId: groupId,
      netBalances: const {'uday': 1250, 'rahul': -1250},
      debts: const [
        DebtEntry(
          fromUserId: 'rahul',
          toUserId: 'uday',
          amountCents: 1250,
          currencyCode: 'USD',
        ),
      ],
      simplifiedDebts: const [
        DebtEntry(
          fromUserId: 'rahul',
          toUserId: 'uday',
          amountCents: 1250,
          currencyCode: 'USD',
        ),
      ],
      totalExpensesCents: 2500,
      totalSettlementsCents: 0,
      calculatedAt: DateTime(2026, 5, 13),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coinsCurrencyFormatterProvider.overrideWithValue(
            CurrencyFormatter.fromCode('USD'),
          ),
          groupByIdProvider(groupId).overrideWith((ref) => Stream.value(group)),
          groupMembersProvider(
            groupId,
          ).overrideWith((ref) => Stream.value(members)),
          groupExpensesProvider(
            groupId,
          ).overrideWith((ref) => Stream.value(const [])),
          groupBalanceSummaryProvider(
            groupId,
          ).overrideWith((ref) async => summary),
          groupSettlementsProvider(
            groupId,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: GroupDetailScreen(groupId: groupId)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balances'));
    await tester.pumpAndSettle();

    expect(find.text('Rahul owes Uday'), findsOneWidget);
    expect(find.textContaining(r'$12.50'), findsOneWidget);
    expect(find.text('All debts settled!'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Settle'), findsOneWidget);
  });

  testWidgets('shows expense payer names instead of raw user ids', (
    tester,
  ) async {
    const groupId = 'group_1';
    final now = DateTime(2026, 5, 13);
    final group = Group(
      id: groupId,
      name: 'Goa Trip',
      defaultCurrencyCode: 'USD',
      creatorId: 'uday',
      createdAt: now,
    );
    final members = [
      GroupMember(
        id: 'member_1',
        groupId: groupId,
        userId: 'uday',
        displayName: 'Uday',
        joinedAt: now,
      ),
      GroupMember(
        id: 'member_2',
        groupId: groupId,
        userId: 'rahul',
        displayName: 'Rahul',
        joinedAt: now,
      ),
    ];
    final expense = SharedExpense(
      id: 'expense_1',
      groupId: groupId,
      description: 'Dinner',
      totalAmountCents: 2400,
      currencyCode: 'USD',
      categoryId: 'food',
      paidByUserId: 'uday',
      splits: [
        SplitEntry(
          id: 'split_1',
          sharedExpenseId: 'expense_1',
          userId: 'uday',
          amountCents: 1200,
          createdAt: now,
        ),
        SplitEntry(
          id: 'split_2',
          sharedExpenseId: 'expense_1',
          userId: 'rahul',
          amountCents: 1200,
          createdAt: now,
        ),
      ],
      expenseDate: now,
      createdAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coinsCurrencyFormatterProvider.overrideWithValue(
            CurrencyFormatter.fromCode('USD'),
          ),
          groupByIdProvider(groupId).overrideWith((ref) => Stream.value(group)),
          groupMembersProvider(
            groupId,
          ).overrideWith((ref) => Stream.value(members)),
          groupExpensesProvider(
            groupId,
          ).overrideWith((ref) => Stream.value([expense])),
          groupBalanceSummaryProvider(
            groupId,
          ).overrideWith((ref) async => _settledSummary(groupId, now)),
          groupSettlementsProvider(
            groupId,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: GroupDetailScreen(groupId: groupId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Paid by Uday'), findsOneWidget);
    expect(find.text('Paid by uday'), findsNothing);
  });

  testWidgets('shows completed settlement history with member names', (
    tester,
  ) async {
    const groupId = 'group_1';
    final now = DateTime(2026, 5, 13);
    final group = Group(
      id: groupId,
      name: 'Goa Trip',
      defaultCurrencyCode: 'USD',
      creatorId: 'uday',
      createdAt: now,
    );
    final members = [
      GroupMember(
        id: 'member_1',
        groupId: groupId,
        userId: 'uday',
        displayName: 'Uday',
        joinedAt: now,
      ),
      GroupMember(
        id: 'member_2',
        groupId: groupId,
        userId: 'rahul',
        displayName: 'Rahul',
        joinedAt: now,
      ),
    ];
    final settlement = Settlement(
      id: 'settlement_1',
      groupId: groupId,
      fromUserId: 'rahul',
      toUserId: 'uday',
      amountCents: 1250,
      currencyCode: 'USD',
      status: SettlementStatus.completed,
      settlementDate: now,
      createdAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coinsCurrencyFormatterProvider.overrideWithValue(
            CurrencyFormatter.fromCode('USD'),
          ),
          groupByIdProvider(groupId).overrideWith((ref) => Stream.value(group)),
          groupMembersProvider(
            groupId,
          ).overrideWith((ref) => Stream.value(members)),
          groupExpensesProvider(
            groupId,
          ).overrideWith((ref) => Stream.value(const [])),
          groupBalanceSummaryProvider(
            groupId,
          ).overrideWith((ref) async => _settledSummary(groupId, now)),
          groupSettlementsProvider(
            groupId,
          ).overrideWith((ref) => Stream.value([settlement])),
        ],
        child: const MaterialApp(home: GroupDetailScreen(groupId: groupId)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balances'));
    await tester.pumpAndSettle();

    expect(find.text('Settlement History'), findsOneWidget);
    expect(find.text('Rahul paid Uday'), findsOneWidget);
    expect(find.textContaining(r'$12.50'), findsWidgets);
  });

  testWidgets('super-app add expense sheet offers manual and bill upload', (
    tester,
  ) async {
    const groupId = 'group_super';
    final group = _sampleGroup(groupId);

    await tester.pumpWidget(
      _detailHost(
        groupId: groupId,
        group: group,
        screen: buildSuperAppGroupDetail(groupId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Add manually'), findsOneWidget);
    expect(find.text('Upload bill'), findsOneWidget);

    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();

    expect(find.byType(AddSplitExpenseScreen), findsOneWidget);
  });

  testWidgets('standalone detail skips bill upload and opens manual split', (
    tester,
  ) async {
    const groupId = 'group_standalone';
    final group = _sampleGroup(groupId);

    await tester.pumpWidget(
      _detailHost(
        groupId: groupId,
        group: group,
        screen: const GroupDetailScreen(groupId: groupId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Upload bill'), findsNothing);
    expect(find.byType(AddSplitExpenseScreen), findsOneWidget);
  });

  testWidgets('local invite share uses generated codes when missing', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    var sharedText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          sharedText = call.arguments['text'] as String? ?? '';
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
    });

    const groupId = 'group_local_share';
    final group = _sampleGroup(groupId);
    final repository = FakeGroupRepository();

    await tester.pumpWidget(
      _detailHost(
        groupId: groupId,
        group: group,
        repository: repository,
        screen: const GroupDetailScreen(groupId: groupId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share invite'));
    await tester.pumpAndSettle();

    expect(repository.lastGenerateInviteGroupId, groupId);
    expect(sharedText, contains('Join Goa Trip on Airo Coin'));
    expect(sharedText, contains('INVITE01'));
  });
}

Group _sampleGroup(String groupId) {
  return Group(
    id: groupId,
    name: 'Goa Trip',
    defaultCurrencyCode: 'USD',
    creatorId: 'uday',
    createdAt: DateTime(2026, 5, 13),
  );
}

Widget _detailHost({
  required String groupId,
  required Group group,
  required Widget screen,
  FakeGroupRepository? repository,
}) {
  final fakeRepository = repository ?? FakeGroupRepository();
  final members = [
    GroupMember(
      id: 'member_1',
      groupId: groupId,
      userId: 'uday',
      displayName: 'Uday',
      joinedAt: DateTime(2026, 5, 13),
    ),
  ];

  return ProviderScope(
    overrides: [
      coinsCurrencyFormatterProvider.overrideWithValue(
        CurrencyFormatter.fromCode('USD'),
      ),
      groupRepositoryProvider.overrideWithValue(fakeRepository),
      groupByIdProvider(groupId).overrideWith((ref) => Stream.value(group)),
      groupMembersProvider(
        groupId,
      ).overrideWith((ref) => Stream.value(members)),
      groupExpensesProvider(
        groupId,
      ).overrideWith((ref) => Stream.value(const [])),
      groupBalanceSummaryProvider(
        groupId,
      ).overrideWith((ref) async => _settledSummary(groupId, group.createdAt)),
      groupSettlementsProvider(
        groupId,
      ).overrideWith((ref) => Stream.value(const [])),
    ],
    child: MaterialApp(home: screen),
  );
}

BalanceSummary _settledSummary(String groupId, DateTime now) {
  return BalanceSummary(
    groupId: groupId,
    netBalances: const {},
    debts: const [],
    simplifiedDebts: const [],
    totalExpensesCents: 0,
    totalSettlementsCents: 0,
    calculatedAt: now,
  );
}
