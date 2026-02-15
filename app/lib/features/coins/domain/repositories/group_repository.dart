import '../entities/group.dart';
import '../entities/group_member.dart';
import '../entities/shared_expense.dart';

/// Result type for repository operations
typedef Result<T> = ({T? data, String? error});

/// Group repository interface
///
/// Defines the contract for group data access operations.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-018)
abstract class GroupRepository {
  // ==================== Group Operations ====================

  /// Find a group by ID
  Future<Result<Group>> findById(String id);

  /// Find a group by invite code
  Future<Result<Group?>> findByInviteCode(String code);

  /// Find all groups for the current user
  Future<Result<List<Group>>> findAll();

  /// Find active (non-archived) groups
  Future<Result<List<Group>>> findActive();

  /// Create a new group
  Future<Result<Group>> create(Group group);

  /// Update an existing group
  Future<Result<Group>> update(Group group);

  /// Archive a group
  Future<Result<void>> archive(String id);

  /// Delete a group permanently
  Future<Result<void>> delete(String id);

  /// Generate a new invite code for a group
  Future<Result<String>> generateInviteCode(String groupId);

  /// Watch all groups
  Stream<List<Group>> watchAll();

  /// Watch a specific group
  Stream<Group?> watchById(String id);

  // ==================== Member Operations ====================

  /// Get all members of a group
  Future<Result<List<GroupMember>>> getMembers(String groupId);

  /// Add a member to a group
  Future<Result<GroupMember>> addMember(GroupMember member);

  /// Update a member's details
  Future<Result<GroupMember>> updateMember(GroupMember member);

  /// Remove a member from a group
  Future<Result<void>> removeMember(String groupId, String userId);

  /// Watch group members
  Stream<List<GroupMember>> watchMembers(String groupId);

  // ==================== Expense Operations ====================

  /// Get all expenses for a group
  Future<Result<List<SharedExpense>>> getExpenses(String groupId);

  /// Get expenses for a specific member
  Future<Result<List<SharedExpense>>> getExpensesByMember(
    String groupId,
    String userId,
  );

  /// Add an expense to a group
  Future<Result<SharedExpense>> addExpense(SharedExpense expense);

  /// Update an expense
  Future<Result<SharedExpense>> updateExpense(SharedExpense expense);

  /// Delete an expense (soft delete)
  Future<Result<void>> deleteExpense(String expenseId);

  /// Watch group expenses
  Stream<List<SharedExpense>> watchExpenses(String groupId);
}

