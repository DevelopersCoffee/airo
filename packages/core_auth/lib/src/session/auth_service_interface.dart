import 'package:core_domain/core_domain.dart';
import '../models/user.dart';
import '../models/auth_result.dart';
import 'auth_state.dart';

/// Abstract authentication service interface.
///
/// Implementations can be swapped for different auth backends
/// (local, Firebase, custom server, etc.).
abstract interface class AuthServiceInterface {
  /// Stream of authentication state changes.
  Stream<AuthState> get authStateChanges;

  /// Get current authentication state.
  AuthState get currentState;

  /// Get current user if authenticated.
  User? get currentUser;

  /// Check if user is currently authenticated.
  bool get isAuthenticated;

  /// Initialize the auth service.
  Future<Result<void>> initialize();

  /// Login with credentials.
  Future<AuthResult> login(LoginCredentials credentials);

  /// Register a new user.
  Future<AuthResult> register(RegisterCredentials credentials);

  /// Logout current user.
  Future<Result<void>> logout();

  /// Refresh the current session/token.
  Future<Result<void>> refreshSession();

  /// Update current user profile.
  Future<Result<User>> updateProfile({
    String? displayName,
    String? email,
    String? avatarUrl,
  });

  /// Change password.
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Delete account.
  Future<Result<void>> deleteAccount();

  /// Dispose resources.
  Future<void> dispose();
}

/// Token storage interface for persisting auth tokens.
abstract interface class TokenStorage {
  /// Get stored access token.
  Future<String?> getAccessToken();

  /// Get stored refresh token.
  Future<String?> getRefreshToken();

  /// Store tokens.
  Future<void> storeTokens({
    required String accessToken,
    String? refreshToken,
  });

  /// Clear stored tokens.
  Future<void> clearTokens();

  /// Check if tokens exist.
  Future<bool> hasTokens();
}

/// User storage interface for persisting user data.
abstract interface class UserStorage {
  /// Get stored user.
  Future<User?> getUser();

  /// Store user.
  Future<void> storeUser(User user);

  /// Clear stored user.
  Future<void> clearUser();
}

