import '../entities/settlement.dart';

/// Result type for repository operations
typedef Result<T> = ({T? data, String? error});

/// Settlement repository interface
///
/// Defines the contract for settlement data access operations.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-029)
abstract class SettlementRepository {
  /// Find a settlement by ID
  Future<Result<Settlement>> findById(String id);

  /// Find all settlements for a group
  Future<Result<List<Settlement>>> findByGroup(String groupId);

  /// Find settlements between two users in a group
  Future<Result<List<Settlement>>> findBetweenUsers(
    String groupId,
    String userId1,
    String userId2,
  );

  /// Find settlements by status
  Future<Result<List<Settlement>>> findByStatus(
    String groupId,
    SettlementStatus status,
  );

  /// Find pending settlements for a user
  Future<Result<List<Settlement>>> findPendingForUser(String userId);

  /// Create a new settlement
  Future<Result<Settlement>> create(Settlement settlement);

  /// Update a settlement
  Future<Result<Settlement>> update(Settlement settlement);

  /// Mark a settlement as completed
  Future<Result<Settlement>> complete(String id);

  /// Cancel a settlement
  Future<Result<Settlement>> cancel(String id);

  /// Delete a settlement permanently
  Future<Result<void>> delete(String id);

  /// Watch settlements for a group
  Stream<List<Settlement>> watchByGroup(String groupId);

  /// Watch pending settlements for a user
  Stream<List<Settlement>> watchPendingForUser(String userId);

  /// Get total settled amount for a group
  Future<Result<int>> getTotalSettled(String groupId);

  /// Get settlement history between two users
  Future<Result<List<Settlement>>> getHistory(
    String userId1,
    String userId2, {
    int limit = 20,
  });
}

