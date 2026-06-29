import 'package:airo_app/core/database/app_database.dart';
import 'package:airo_app/features/coins/application/use_cases/add_split_use_case.dart';
import 'package:airo_app/features/coins/application/use_cases/create_group_use_case.dart';
import 'package:airo_app/features/coins/data/datasources/coins_local_datasource_impl.dart';
import 'package:airo_app/features/coins/data/mappers/group_mapper.dart';
import 'package:airo_app/features/coins/data/repositories/group_repository_impl.dart';
import 'package:airo_app/features/coins/domain/entities/group.dart';
import 'package:airo_app/features/coins/domain/entities/group_member.dart';
import 'package:airo_app/features/coins/domain/entities/split_entry.dart';
import 'package:airo_app/features/coins/domain/services/split_calculator.dart';
import 'package:airo_app/features/coins/domain/entities/settlement.dart';
import 'package:airo_app/features/coins/domain/services/balance_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GroupRepositoryImpl repository;
  late AddSplitUseCase addSplitUseCase;
  late CreateGroupUseCase createGroupUseCase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = GroupRepositoryImpl(
      CoinsLocalDatasourceImpl(db),
      GroupMapper(),
    );
    addSplitUseCase = AddSplitUseCase(repository, SplitCalculatorImpl());
    createGroupUseCase = CreateGroupUseCase(repository);
  });

  tearDown(() async {
    await db.close();
  });

  group('Coins split workflow', () {
    test('creates a group with the creator as admin member', () async {
      final result = await createGroupUseCase.execute(
        const CreateGroupParams(
          name: 'Roommates',
          creatorId: 'uday',
          creatorDisplayName: 'Uday',
        ),
      );

      expect(result.error, isNull);
      final members = await repository.getMembers(result.data!.id);

      expect(members.error, isNull);
      expect(members.data, hasLength(1));
      expect(members.data!.single.userId, 'uday');
      expect(members.data!.single.displayName, 'Uday');
      expect(members.data!.single.role, MemberRole.admin);
    });

    test(
      'creates a split expense and reads it back with calculated splits',
      () async {
        final now = DateTime(2026, 5, 13);
        final group = Group(
          id: 'trip_goa',
          name: 'Goa Trip',
          defaultCurrencyCode: 'INR',
          creatorId: 'uday',
          createdAt: now,
        );

        await repository.create(group);
        await repository.addMember(
          GroupMember(
            id: 'member_uday',
            groupId: group.id,
            userId: 'uday',
            displayName: 'Uday',
            role: MemberRole.admin,
            joinedAt: now,
          ),
        );
        await repository.addMember(
          GroupMember(
            id: 'member_rahul',
            groupId: group.id,
            userId: 'rahul',
            displayName: 'Rahul',
            joinedAt: now,
          ),
        );

        final result = await addSplitUseCase.execute(
          AddSplitParams(
            groupId: group.id,
            description: 'Dinner',
            totalAmountCents: 10000,
            paidByUserId: 'uday',
            splitType: SplitType.equal,
            participantIds: const ['uday', 'rahul'],
            expenseDate: now,
          ),
        );

        expect(result.error, isNull);
        final expenses = await repository.getExpenses(group.id);

        expect(expenses.error, isNull);
        expect(expenses.data, hasLength(1));
        final expense = expenses.data!.single;
        expect(expense.description, 'Dinner');
        expect(expense.totalAmountCents, 10000);
        expect(expense.paidByUserId, 'uday');
        expect(expense.splits, hasLength(2));
        expect(
          expense.splits.map((split) => split.amountCents),
          unorderedEquals([5000, 5000]),
        );
      },
    );

    test(
      'uses group currency for created split expenses and balances',
      () async {
        final groupResult = await createGroupUseCase.execute(
          const CreateGroupParams(
            name: 'US Trip',
            creatorId: 'uday',
            creatorDisplayName: 'Uday',
            defaultCurrencyCode: 'USD',
          ),
        );
        expect(groupResult.error, isNull);

        final memberResult = await repository.addMember(
          GroupMember(
            id: 'member_rahul',
            groupId: groupResult.data!.id,
            userId: 'rahul',
            displayName: 'Rahul',
            currencyCode: 'USD',
            joinedAt: DateTime(2026, 5, 13),
          ),
        );
        expect(memberResult.error, isNull);

        final expenseResult = await addSplitUseCase.execute(
          AddSplitParams(
            groupId: groupResult.data!.id,
            description: 'Cab',
            totalAmountCents: 2500,
            currencyCode: groupResult.data!.defaultCurrencyCode,
            paidByUserId: 'uday',
            participantIds: const ['uday', 'rahul'],
          ),
        );
        expect(expenseResult.error, isNull);
        expect(expenseResult.data!.currencyCode, 'USD');

        final expenses = await repository.getExpenses(groupResult.data!.id);
        final summary = await BalanceEngineImpl().calculateBalanceSummary(
          groupId: groupResult.data!.id,
          expenses: expenses.data!,
          settlements: const <Settlement>[],
        );

        expect(summary.simplifiedDebts, hasLength(1));
        expect(summary.simplifiedDebts.single.currencyCode, 'USD');
      },
    );

    test('creates an itemized receipt split with per-item ownership', () async {
      final now = DateTime(2026, 5, 20);
      final group = Group(
        id: 'instamart_group',
        name: 'Flat groceries',
        defaultCurrencyCode: 'INR',
        creatorId: 'uday',
        createdAt: now,
      );

      await repository.create(group);
      await repository.addMember(
        GroupMember(
          id: 'member_uday',
          groupId: group.id,
          userId: 'uday',
          displayName: 'Uday',
          role: MemberRole.admin,
          joinedAt: now,
        ),
      );
      await repository.addMember(
        GroupMember(
          id: 'member_rahul',
          groupId: group.id,
          userId: 'rahul',
          displayName: 'Rahul',
          joinedAt: now,
        ),
      );

      final result = await addSplitUseCase.execute(
        AddSplitParams(
          groupId: group.id,
          description: 'Instamart (3 items)',
          totalAmountCents: 22300,
          paidByUserId: 'uday',
          splitType: SplitType.itemized,
          participantIds: const ['uday', 'rahul'],
          itemizedItems: const [
            ItemizedSplitInput(
              itemId: 'potato',
              name: 'Potato',
              amountCents: 4500,
              participantIds: ['uday'],
            ),
            ItemizedSplitInput(
              itemId: 'milk',
              name: 'Milk',
              amountCents: 5800,
              participantIds: ['rahul'],
            ),
            ItemizedSplitInput(
              itemId: 'rice',
              name: 'Rice',
              amountCents: 12000,
              participantIds: ['uday', 'rahul'],
            ),
          ],
          expenseDate: now,
        ),
      );

      expect(result.error, isNull);
      final expense = result.data!;
      expect(expense.splitType, SplitType.itemized);
      expect(expense.areSplitsValid, isTrue);
      expect(
        expense.splits.map((split) => (split.userId, split.amountCents)),
        unorderedEquals([('uday', 10500), ('rahul', 11800)]),
      );
      expect(
        expense.splits.firstWhere((split) => split.userId == 'uday').itemIds,
        unorderedEquals(['potato', 'rice']),
      );
      expect(
        expense.splits.firstWhere((split) => split.userId == 'rahul').itemIds,
        unorderedEquals(['milk', 'rice']),
      );
    });
  });
}
