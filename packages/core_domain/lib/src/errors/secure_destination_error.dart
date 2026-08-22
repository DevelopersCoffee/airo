import 'app_error.dart';

/// Encryption key or encrypted storage is unavailable; destination writes fail
/// closed while reads may continue from a compatibility source.
class SecureDestinationUnavailableError extends AppError {
  SecureDestinationUnavailableError(
    String message, {
    Object? originalError,
    StackTrace? originalStack,
  }) : super(
         'secure_destination_unavailable',
         message,
         statusCode: 503,
         originalError: originalError,
         originalStack: originalStack,
       );
}
