import 'package:airo_app/core/utils/currency_formatter.dart';
import 'package:airo_app/core/utils/locale_settings.dart';
import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:airo_app/features/coins/domain/entities/group.dart';
import 'package:airo_app/features/coins/domain/entities/group_member.dart';
import 'package:airo_app/features/coins/domain/entities/shared_expense.dart';
import 'package:airo_app/features/coins/domain/repositories/group_repository.dart';
import 'package:airo_app/features/coins/presentation/screens/add_split_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers supported custom split options', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Equal Split'), findsOneWidget);
    expect(find.text('By Percentage'), findsOneWidget);
    expect(find.text('Exact Amounts'), findsOneWidget);
    expect(find.text('By Shares'), findsOneWidget);
    expect(find.text('By Items'), findsNothing);
  });

  testWidgets('shows percentage inputs and preview amounts', (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField).first, '100');
    await tester.tap(find.byType(CheckboxListTile).at(0));
    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('By Percentage'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Uday %'), '25');
    await tester.enterText(find.widgetWithText(TextFormField, 'Rahul %'), '75');
    await tester.pumpAndSettle();

    expect(find.text('Custom split'), findsOneWidget);
    expect(find.textContaining(r'$25.00'), findsOneWidget);
    expect(find.textContaining(r'$75.00'), findsOneWidget);
  });

  testWidgets('saves exact split amounts', (tester) async {
    final repository = _FakeGroupRepository();
    await _pumpScreen(tester, repository: repository);

    await tester.enterText(find.byType(TextFormField).first, '100');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Dinner',
    );
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.tap(find.byType(CheckboxListTile).at(0));
    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exact Amounts'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Uday amount'),
      '40',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Rahul amount'),
      '60',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.savedExpense, isNotNull);
    expect(repository.savedExpense!.splitType.name, 'exact');
    expect(repository.savedExpense!.splits, hasLength(2));
    expect(
      repository.savedExpense!.splits.map((split) => split.amountCents),
      unorderedEquals([4000, 6000]),
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  _FakeGroupRepository? repository,
}) async {
  final fakeRepository = repository ?? _FakeGroupRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(fakeRepository),
        currencyFormatterProvider.overrideWithValue(
          CurrencyFormatter.fromCode('USD'),
        ),
        groupMembersProvider(
          'group_1',
        ).overrideWith((ref) => Stream.value(_members)),
      ],
      child: const MaterialApp(home: AddSplitExpenseScreen(groupId: 'group_1')),
    ),
  );
  await tester.pump();
}

final _members = [
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
];

class _FakeGroupRepository implements GroupRepository {
  SharedExpense? savedExpense;

  @override
  Future<Result<SharedExpense>> addExpense(SharedExpense expense) async {
    savedExpense = expense;
    return (data: expense, error: null);
  }

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) =>
      Stream.value(_members);

  @override
  Future<Result<void>> archive(String id) async => (data: null, error: null);

  @override
  Future<Result<GroupMember>> addMember(GroupMember member) async =>
      (data: member, error: null);

  @override
  Future<Result<Group>> create(Group group) async => (data: group, error: null);

  @override
  Future<Result<void>> delete(String id) async => (data: null, error: null);

  @override
  Future<Result<void>> deleteExpense(String expenseId) async =>
      (data: null, error: null);

  @override
  Future<Result<List<Group>>> findActive() async =>
      (data: const <Group>[], error: null);

  @override
  Future<Result<List<Group>>> findAll() async =>
      (data: const <Group>[], error: null);

  @override
  Future<Result<Group>> findById(String id) async =>
      (data: null, error: 'not found');

  @override
  Future<Result<Group?>> findByInviteCode(String code) async =>
      (data: null, error: null);

  @override
  Future<Result<String>> generateInviteCode(String groupId) async =>
      (data: 'ABC123', error: null);

  @override
  Future<Result<List<SharedExpense>>> getExpenses(String groupId) async =>
      (data: const <SharedExpense>[], error: null);

  @override
  Future<Result<List<SharedExpense>>> getExpensesByMember(
    String groupId,
    String userId,
  ) async => (data: const <SharedExpense>[], error: null);

  @override
  Future<Result<List<GroupMember>>> getMembers(String groupId) async =>
      (data: _members, error: null);

  @override
  Future<Result<void>> removeMember(String groupId, String userId) async =>
      (data: null, error: null);

  @override
  Future<Result<Group>> update(Group group) async => (data: group, error: null);

  @override
  Future<Result<SharedExpense>> updateExpense(SharedExpense expense) async =>
      (data: expense, error: null);

  @override
  Future<Result<GroupMember>> updateMember(GroupMember member) async =>
      (data: member, error: null);

  @override
  Stream<List<Group>> watchAll() => Stream.value(const []);

  @override
  Stream<Group?> watchById(String id) => Stream.value(null);

  @override
  Stream<List<SharedExpense>> watchExpenses(String groupId) =>
      Stream.value(const []);
}
