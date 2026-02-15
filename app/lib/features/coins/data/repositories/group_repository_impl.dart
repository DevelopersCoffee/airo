import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/repositories/group_repository.dart';
import '../datasources/coins_local_datasource.dart';
import '../mappers/group_mapper.dart';

/// Implementation of GroupRepository
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/PROJECT_STRUCTURE.md
class GroupRepositoryImpl implements GroupRepository {
  final CoinsLocalDatasource _localDatasource;
  final GroupMapper _mapper;

  GroupRepositoryImpl(this._localDatasource, this._mapper);

  // ==================== Group Operations ====================

  @override
  Future<Result<Group>> findById(String id) async {
    try {
      final entity = await _localDatasource.getGroupById(id);
      if (entity == null) {
        return (data: null, error: 'Group not found');
      }
      return (data: _mapper.toDomain(entity), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch group: $e');
    }
  }

  @override
  Future<Result<Group?>> findByInviteCode(String code) async {
    try {
      final entity = await _localDatasource.getGroupByInviteCode(code);
      return (data: entity != null ? _mapper.toDomain(entity) : null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch group: $e');
    }
  }

  @override
  Future<Result<List<Group>>> findAll() async {
    try {
      final entities = await _localDatasource.getAllGroups();
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch groups: $e');
    }
  }

  @override
  Future<Result<List<Group>>> findActive() async {
    try {
      final entities = await _localDatasource.getActiveGroups();
      return (data: entities.map(_mapper.toDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch groups: $e');
    }
  }

  @override
  Future<Result<Group>> create(Group group) async {
    try {
      final entity = _mapper.toEntity(group);
      await _localDatasource.insertGroup(entity);
      return (data: group, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to create group: $e');
    }
  }

  @override
  Future<Result<Group>> update(Group group) async {
    try {
      final entity = _mapper.toEntity(group);
      await _localDatasource.updateGroup(entity);
      return (data: group, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to update group: $e');
    }
  }

  @override
  Future<Result<void>> archive(String id) async {
    try {
      await _localDatasource.archiveGroup(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to archive group: $e');
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _localDatasource.deleteGroup(id);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to delete group: $e');
    }
  }

  @override
  Future<Result<String>> generateInviteCode(String groupId) async {
    try {
      final code = await _localDatasource.generateGroupInviteCode(groupId);
      return (data: code, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to generate invite code: $e');
    }
  }

  @override
  Stream<List<Group>> watchAll() {
    return _localDatasource
        .watchAllGroups()
        .map((entities) => entities.map(_mapper.toDomain).toList());
  }

  @override
  Stream<Group?> watchById(String id) {
    return _localDatasource
        .watchGroupById(id)
        .map((entity) => entity != null ? _mapper.toDomain(entity) : null);
  }

  // ==================== Member Operations ====================

  @override
  Future<Result<List<GroupMember>>> getMembers(String groupId) async {
    try {
      final entities = await _localDatasource.getGroupMembers(groupId);
      return (data: entities.map(_mapper.memberToDomain).toList(), error: null);
    } catch (e) {
      return (data: null, error: 'Failed to fetch members: $e');
    }
  }

  @override
  Future<Result<GroupMember>> addMember(GroupMember member) async {
    try {
      final entity = _mapper.memberToEntity(member);
      await _localDatasource.insertGroupMember(entity);
      return (data: member, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to add member: $e');
    }
  }

  @override
  Future<Result<GroupMember>> updateMember(GroupMember member) async {
    try {
      final entity = _mapper.memberToEntity(member);
      await _localDatasource.updateGroupMember(entity);
      return (data: member, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to update member: $e');
    }
  }

  @override
  Future<Result<void>> removeMember(String groupId, String userId) async {
    try {
      await _localDatasource.removeGroupMember(groupId, userId);
      return (data: null, error: null);
    } catch (e) {
      return (data: null, error: 'Failed to remove member: $e');
    }
  }

  @override
  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _localDatasource
        .watchGroupMembers(groupId)
        .map((entities) => entities.map(_mapper.memberToDomain).toList());
  }

  // Member & Expense operations continued in part 2...
  // TODO: Add expense operations

  @override
  Future<Result<List<SharedExpense>>> getExpenses(String groupId) async {
    // TODO: Implement
    return (data: [], error: null);
  }

  @override
  Future<Result<List<SharedExpense>>> getExpensesByMember(
    String groupId,
    String userId,
  ) async {
    // TODO: Implement
    return (data: [], error: null);
  }

  @override
  Future<Result<SharedExpense>> addExpense(SharedExpense expense) async {
    // TODO: Implement
    return (data: expense, error: null);
  }

  @override
  Future<Result<SharedExpense>> updateExpense(SharedExpense expense) async {
    // TODO: Implement
    return (data: expense, error: null);
  }

  @override
  Future<Result<void>> deleteExpense(String expenseId) async {
    // TODO: Implement
    return (data: null, error: null);
  }

  @override
  Stream<List<SharedExpense>> watchExpenses(String groupId) {
    // TODO: Implement
    return Stream.value([]);
  }
}

