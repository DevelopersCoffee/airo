import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Base class for all failure types in the domain layer.
///
/// Failures represent expected error conditions that can occur during
/// business operations. They are used with [Result] for functional
/// error handling.
@immutable
abstract class Failure extends Equatable {
  const Failure({
    required this.message,
    this.code,
    this.cause,
  });

  /// Human-readable error message
  final String message;

  /// Optional error code for programmatic handling
  final String? code;

  /// Optional underlying cause
  final Object? cause;

  @override
  List<Object?> get props => [message, code, cause];

  @override
  bool? get stringify => true;
}

/// Generic server/network failure
@immutable
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Server error occurred',
    super.code,
    super.cause,
    this.statusCode,
  });

  final int? statusCode;

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// Failure when data cannot be found
@immutable
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Resource not found',
    super.code,
    super.cause,
    this.resourceType,
    this.resourceId,
  });

  final String? resourceType;
  final String? resourceId;

  @override
  List<Object?> get props => [...super.props, resourceType, resourceId];
}

/// Failure for validation errors
@immutable
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code,
    super.cause,
    this.field,
    this.errors = const {},
  });

  /// The field that failed validation (if single field)
  final String? field;

  /// Map of field names to error messages (for multiple fields)
  final Map<String, String> errors;

  @override
  List<Object?> get props => [...super.props, field, errors];
}

/// Failure for authentication errors
@immutable
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed',
    super.code,
    super.cause,
  });
}

/// Failure for authorization/permission errors
@immutable
class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'Permission denied',
    super.code,
    super.cause,
    this.requiredPermission,
  });

  final String? requiredPermission;

  @override
  List<Object?> get props => [...super.props, requiredPermission];
}

/// Failure for network connectivity issues
@immutable
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Network connection failed',
    super.code,
    super.cause,
  });
}

/// Failure for cache/storage operations
@immutable
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Cache operation failed',
    super.code,
    super.cause,
  });
}

/// Failure for database operations
@immutable
class DatabaseFailure extends Failure {
  const DatabaseFailure({
    super.message = 'Database operation failed',
    super.code,
    super.cause,
  });
}

/// Generic unexpected failure
@immutable
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'An unexpected error occurred',
    super.code,
    super.cause,
  });
}

