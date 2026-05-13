import 'package:airo_app/core/utils/currency_formatter.dart';
import 'package:airo_app/core/utils/locale_settings.dart';
import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:airo_app/features/coins/application/providers/settlement_providers.dart';
import 'package:airo_app/features/coins/domain/entities/group.dart';
import 'package:airo_app/features/coins/domain/entities/group_member.dart';
import 'package:airo_app/features/coins/domain/models/balance_summary.dart';
import 'package:airo_app/features/coins/domain/models/debt_entry.dart';
import 'package:airo_app/features/coins/presentation/screens/group_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
          currencyFormatterProvider.overrideWithValue(
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
}
