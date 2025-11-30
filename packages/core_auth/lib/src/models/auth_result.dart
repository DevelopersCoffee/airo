import 'user.dart';

/// Result of an authentication operation.
sealed class AuthResult {
  const AuthResult();

  /// Create a successful result.
  factory AuthResult.success(User user, {String? token, String? refreshToken}) {
    return AuthSuccess(user: user, token: token, refreshToken: refreshToken);
  }

  /// Create a failure result.
  factory AuthResult.failure(String message, {AuthErrorCode? code}) {
    return AuthFailure(message: message, code: code);
  }

  /// Check if the result is successful.
  bool get isSuccess => this is AuthSuccess;

  /// Check if the result is a failure.
  bool get isFailure => this is AuthFailure;

  /// Get the user if successful, null otherwise.
  User? get userOrNull => switch (this) {
        AuthSuccess(user: final u) => u,
        AuthFailure() => null,
      };

  /// Get the error message if failed, null otherwise.
  String? get errorOrNull => switch (this) {
        AuthSuccess() => null,
        AuthFailure(message: final m) => m,
      };
}

/// Successful authentication result.
class AuthSuccess extends AuthResult {
  final User user;
  final String? token;
  final String? refreshToken;

  const AuthSuccess({
    required this.user,
    this.token,
    this.refreshToken,
  });
}

/// Failed authentication result.
class AuthFailure extends AuthResult {
  final String message;
  final AuthErrorCode? code;

  const AuthFailure({
    required this.message,
    this.code,
  });
}

/// Authentication error codes.
enum AuthErrorCode {
  invalidCredentials,
  userNotFound,
  userDisabled,
  emailNotVerified,
  weakPassword,
  emailAlreadyInUse,
  usernameAlreadyInUse,
  networkError,
  serverError,
  tokenExpired,
  sessionExpired,
  unknown,
}

/// Extension to get human-readable messages for error codes.
extension AuthErrorCodeMessage on AuthErrorCode {
  String get message => switch (this) {
        AuthErrorCode.invalidCredentials => 'Invalid username or password',
        AuthErrorCode.userNotFound => 'User not found',
        AuthErrorCode.userDisabled => 'This account has been disabled',
        AuthErrorCode.emailNotVerified => 'Please verify your email address',
        AuthErrorCode.weakPassword => 'Password is too weak',
        AuthErrorCode.emailAlreadyInUse => 'Email is already in use',
        AuthErrorCode.usernameAlreadyInUse => 'Username is already taken',
        AuthErrorCode.networkError => 'Network error. Please check your connection',
        AuthErrorCode.serverError => 'Server error. Please try again later',
        AuthErrorCode.tokenExpired => 'Session expired. Please login again',
        AuthErrorCode.sessionExpired => 'Session expired. Please login again',
        AuthErrorCode.unknown => 'An unknown error occurred',
      };
}

