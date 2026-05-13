import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:airo_app/features/coins/domain/entities/group_member.dart';
import 'package:airo_app/features/coins/presentation/screens/add_split_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('only offers equal split until custom split inputs exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupMembersProvider('group_1').overrideWith(
            (ref) => Stream.value([
              GroupMember(
                id: 'member_1',
                groupId: 'group_1',
                userId: 'uday',
                displayName: 'Uday',
                joinedAt: DateTime(2026, 5, 13),
              ),
              GroupMember(
                id: 'member_2',
                groupId: 'group_1',
                userId: 'rahul',
                displayName: 'Rahul',
                joinedAt: DateTime(2026, 5, 13),
              ),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: AddSplitExpenseScreen(groupId: 'group_1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Equal Split'), findsOneWidget);
    expect(find.text('By Percentage'), findsNothing);
    expect(find.text('Exact Amounts'), findsNothing);
    expect(find.text('By Shares'), findsNothing);
  });
}
