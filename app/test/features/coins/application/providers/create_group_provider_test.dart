import 'package:airo_app/core/utils/currency_formatter.dart';
import 'package:airo_app/core/utils/locale_settings.dart';
import 'package:airo_app/features/coins/application/providers/group_providers.dart';
import 'package:airo_app/features/coins/domain/entities/group.dart';
import 'package:airo_app/features/coins/domain/entities/group_member.dart';
import 'package:airo_app/features/coins/domain/entities/shared_expense.dart';
import 'package:airo_app/features/coins/domain/repositories/group_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('createGroupFromInput uses the current user currency', () async {
    final repository = _CapturingGroupRepository();
    final container = ProviderContainer(
      overrides: [
        currencyFormatterProvider.overrideWithValue(
          CurrencyFormatter.fromCode('USD'),
        ),
        groupRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(createGroupProvider.notifier)
        .createGroupFromInput(
          name: 'Roommates',
          creatorId: 'uday',
          creatorDisplayName: 'Uday',
        );

    expect(repository.createdGroup?.defaultCurrencyCode, 'USD');
    expect(repository.addedMember?.currencyCode, 'USD');
  });
}

class _CapturingGroupRepository implements GroupRepository {
  Group? createdGroup;
  GroupMember? addedMember;

  @override
  Future<Result<Group>> create(Group group) async {
    createdGroup = group;
    return (data: group, error: null);
  }

  @override
  Future<Result<GroupMember>> addMember(GroupMember member) async {
    addedMember = member;
    return (data: member, error: null);
  }

  @override
  Future<Result<void>> archive(String id) async => (data: null, error: null);

  @override
  Future<Result<void>> delete(String id) async => (data: null, error: null);

  @override
  Future<Result<void>> deleteExpense(String expenseId) async =>
      (data: null, error: null);

  @override
  Future<Result<Group?>> findByInviteCode(String code) async =>
      (data: null, error: null);

  @override
  Future<Result<List<Group>>> findActive() async =>
      (data: <Group>[], error: null);

  @override
  Future<Result<List<Group>>> findAll() async => (data: <Group>[], error: null);

  @override
  Future<Result<Group>> findById(String id) async =>
      (data: createdGroup, error: null);

  @override
  Future<Result<String>> generateInviteCode(String groupId) async =>
      (data: 'ABC123', error: null);

  @override
  Future<Result<List<SharedExpense>>> getExpenses(String groupId) async =>
      (data: <SharedExpense>[], error: null);

  @override
  Future<Result<List<SharedExpense>>> getExpensesByMember(
    String groupId,
    String userId,
  ) async => (data: <SharedExpense>[], error: null);

  @override
  Future<Result<List<GroupMember>>> getMembers(String groupId) async => (
    data: addedMember == null ? <GroupMember>[] : [addedMember!],
    error: null,
  );

  @override
  Future<Result<void>> removeMember(String groupId, String userId) async =>
      (data: null, error: null);

  @override
  Future<Result<Group>> update(Group group) async => (data: group, error: null);

  @override
  Future<Result<SharedExpense>> addExpense(SharedExpense expense) async =>
      (data: expense, error: null);

  @override
  Future<Result<GroupMember>> updateMember(GroupMember member) async =>
      (data: member, error: null);

  @override
  Future<Result<SharedExpense>> updateExpense(SharedExpense expense) async =>
      (data: expense, error: null);

  @override
  Stream<List<Group>> watchAll() =>
      Stream.value(createdGroup == null ? <Group>[] : [createdGroup!]);

  @override
  Stream<Group?> watchById(String id) => Stream.value(createdGroup);

  @override
  Stream<List<SharedExpense>> watchExpenses(String groupId) =>
      Stream.value(const []);

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) =>
      Stream.value(addedMember == null ? <GroupMember>[] : [addedMember!]);
}
