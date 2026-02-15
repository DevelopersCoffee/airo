/// Base class for all Coins feature errors
abstract class CoinsError implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const CoinsError(this.message, {this.code, this.originalError});

  @override
  String toString() => 'CoinsError: $message';
}

/// Validation error for invalid input data
class ValidationError extends CoinsError {
  final String field;

  const ValidationError(
    super.message, {
    required this.field,
    super.code,
  });

  @override
  String toString() => 'ValidationError[$field]: $message';
}

/// Not found error when entity doesn't exist
class NotFoundError extends CoinsError {
  final String entityType;
  final String entityId;

  const NotFoundError({
    required this.entityType,
    required this.entityId,
    super.code,
  }) : super('$entityType with id $entityId not found');

  @override
  String toString() => 'NotFoundError: $entityType[$entityId] not found';
}

/// Database error for persistence failures
class DatabaseError extends CoinsError {
  const DatabaseError(
    super.message, {
    super.code,
    super.originalError,
  });

  @override
  String toString() => 'DatabaseError: $message';
}

/// Authorization error for permission failures
class AuthorizationError extends CoinsError {
  final String action;
  final String? resourceId;

  const AuthorizationError({
    required this.action,
    this.resourceId,
    super.code,
  }) : super('Not authorized to $action${resourceId != null ? ' on $resourceId' : ''}');

  @override
  String toString() => 'AuthorizationError: Not authorized to $action';
}

/// Budget exceeded error
class BudgetExceededError extends CoinsError {
  final String categoryId;
  final int limitCents;
  final int spentCents;

  const BudgetExceededError({
    required this.categoryId,
    required this.limitCents,
    required this.spentCents,
    super.code,
  }) : super('Budget exceeded for category $categoryId');

  int get overageCents => spentCents - limitCents;

  @override
  String toString() =>
      'BudgetExceededError: Over by ${overageCents / 100} in $categoryId';
}

/// Split validation error
class SplitValidationError extends CoinsError {
  final int expectedCents;
  final int actualCents;

  const SplitValidationError({
    required this.expectedCents,
    required this.actualCents,
    super.code,
  }) : super('Split amounts do not sum to total');

  int get differenceCents => actualCents - expectedCents;

  @override
  String toString() =>
      'SplitValidationError: Expected $expectedCents, got $actualCents';
}

/// Group membership error
class GroupMembershipError extends CoinsError {
  final String groupId;
  final String userId;

  const GroupMembershipError({
    required this.groupId,
    required this.userId,
    super.code,
  }) : super('User $userId is not a member of group $groupId');

  @override
  String toString() => 'GroupMembershipError: $message';
}

/// Network/sync error
class SyncError extends CoinsError {
  final bool isRetryable;

  const SyncError(
    super.message, {
    this.isRetryable = true,
    super.code,
    super.originalError,
  });

  @override
  String toString() => 'SyncError: $message (retryable: $isRetryable)';
}

