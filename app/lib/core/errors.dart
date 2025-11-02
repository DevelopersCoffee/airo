/// Base application error
class AppError implements Exception {
  final String code;
  final String message;
  final Object? originalError;
  final StackTrace? originalStack;

  AppError(this.code, this.message, {this.originalError, this.originalStack});

  @override
  String toString() => 'AppError($code): $message';
}

/// Network-related errors
class NetworkError extends AppError {
  NetworkError(
    String message, {
    Object? originalError,
    StackTrace? originalStack,
  }) : super(
         'NETWORK_ERROR',
         message,
         originalError: originalError,
         originalStack: originalStack,
       );
}

/// Authentication errors
class AuthError extends AppError {
  AuthError(String message, {Object? originalError, StackTrace? originalStack})
    : super(
        'AUTH_ERROR',
        message,
        originalError: originalError,
        originalStack: originalStack,
      );
}

/// Validation errors
class ValidationError extends AppError {
  final Map<String, String> fieldErrors;

  ValidationError(
    String message, {
    this.fieldErrors = const {},
    Object? originalError,
    StackTrace? originalStack,
  }) : super(
         'VALIDATION_ERROR',
         message,
         originalError: originalError,
         originalStack: originalStack,
       );
}

/// Not found errors
class NotFoundError extends AppError {
  NotFoundError(
    String message, {
    Object? originalError,
    StackTrace? originalStack,
  }) : super(
         'NOT_FOUND',
         message,
         originalError: originalError,
         originalStack: originalStack,
       );
}

/// Permission errors
class PermissionError extends AppError {
  PermissionError(
    String message, {
    Object? originalError,
    StackTrace? originalStack,
  }) : super(
         'PERMISSION_ERROR',
         message,
         originalError: originalError,
         originalStack: originalStack,
       );
}

/// Storage errors
class StorageError extends AppError {
  StorageError(
    String message, {
    Object? originalError,
    StackTrace? originalStack,
  }) : super(
         'STORAGE_ERROR',
         message,
         originalError: originalError,
         originalStack: originalStack,
       );
}

/// Parse/serialization errors
class ParseError extends AppError {
  ParseError(String message, {Object? originalError, StackTrace? originalStack})
    : super(
        'PARSE_ERROR',
        message,
        originalError: originalError,
        originalStack: originalStack,
      );
}

/// Timeout errors
class TimeoutError extends AppError {
  TimeoutError(
    String message, {
    Object? originalError,
    StackTrace? originalStack,
  }) : super(
         'TIMEOUT_ERROR',
         message,
         originalError: originalError,
         originalStack: originalStack,
       );
}

/// Generic unknown error
class UnknownError extends AppError {
  UnknownError(
    String message, {
    Object? originalError,
    StackTrace? originalStack,
  }) : super(
         'UNKNOWN_ERROR',
         message,
         originalError: originalError,
         originalStack: originalStack,
       );
}
