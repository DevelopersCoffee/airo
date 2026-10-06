import 'package:feature_coins_core/feature_coins_core.dart';

/// Configurable in-memory [GroupRepository] for widget and flow tests.
class FakeGroupRepository implements GroupRepository {
  FakeGroupRepository({
    this.allGroups = const [],
    this.membersByGroup = const {},
    this.inviteLookup,
    this.generateInviteResult = (data: 'INVITE01', error: null),
    this.addExpenseResult,
    this.getMembersResult,
  });

  List<Group> allGroups;
  final Map<String, List<GroupMember>> membersByGroup;
  final Future<Result<Group?>> Function(String code)? inviteLookup;
  final Result<String> generateInviteResult;
  final Future<Result<SharedExpense>> Function(SharedExpense expense)?
  addExpenseResult;
  final Future<Result<List<GroupMember>>> Function(String groupId)?
  getMembersResult;

  SharedExpense? lastAddedExpense;
  String? lastGenerateInviteGroupId;

  List<GroupMember> membersFor(String groupId) =>
      membersByGroup[groupId] ?? const [];

  @override
  Future<Result<SharedExpense>> addExpense(SharedExpense expense) async {
    if (addExpenseResult != null) {
      return addExpenseResult!(expense);
    }
    lastAddedExpense = expense;
    return (data: expense, error: null);
  }

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) async* {
    yield membersFor(groupId);
  }

  @override
  Future<Result<void>> archive(String id) async => (data: null, error: null);

  @override
  Future<Result<GroupMember>> addMember(GroupMember member) async =>
      (data: member, error: null);

  @override
  Future<Result<Group>> create(Group group) async {
    allGroups = [...allGroups, group];
    return (data: group, error: null);
  }

  @override
  Future<Result<void>> delete(String id) async => (data: null, error: null);

  @override
  Future<Result<void>> deleteExpense(String expenseId) async =>
      (data: null, error: null);

  @override
  Future<Result<List<Group>>> findActive() async =>
      (data: allGroups, error: null);

  @override
  Future<Result<List<Group>>> findAll() async => (data: allGroups, error: null);

  @override
  Future<Result<Group>> findById(String id) async {
    for (final group in allGroups) {
      if (group.id == id) return (data: group, error: null);
    }
    return (data: null, error: 'not found');
  }

  @override
  Future<Result<Group?>> findByInviteCode(String code) async {
    if (inviteLookup != null) return inviteLookup!(code);
    for (final group in allGroups) {
      if (group.inviteCode == code) return (data: group, error: null);
    }
    return (data: null, error: null);
  }

  @override
  Future<Result<String>> generateInviteCode(String groupId) async {
    lastGenerateInviteGroupId = groupId;
    return generateInviteResult;
  }

  @override
  Future<Result<List<SharedExpense>>> getExpenses(String groupId) async =>
      (data: const <SharedExpense>[], error: null);

  @override
  Future<Result<List<SharedExpense>>> getExpensesByMember(
    String groupId,
    String userId,
  ) async => (data: const <SharedExpense>[], error: null);

  @override
  Future<Result<List<GroupMember>>> getMembers(String groupId) async {
    if (getMembersResult != null) return getMembersResult!(groupId);
    return (data: membersFor(groupId), error: null);
  }

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
  Stream<List<Group>> watchAll() => Stream.value(allGroups);

  @override
  Stream<Group?> watchById(String id) {
    for (final group in allGroups) {
      if (group.id == id) return Stream.value(group);
    }
    return Stream.value(null);
  }

  @override
  Stream<List<SharedExpense>> watchExpenses(String groupId) =>
      Stream.value(const <SharedExpense>[]);
}
