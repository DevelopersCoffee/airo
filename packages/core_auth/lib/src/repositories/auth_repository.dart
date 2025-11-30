import 'package:core_domain/core_domain.dart';

import '../models/credentials.dart';
import '../models/session.dart';

/// Repository interface for authentication operations
abstract class AuthRepository {
  /// Attempts to login with the given credentials
  Future<Result<Session>> login(Credentials credentials);

  /// Logs out the current session
  Future<Result<void>> logout();

  /// Gets the stored session if available
  Future<Result<Session?>> getStoredSession();

  /// Stores a session for later retrieval
  Future<Result<void>> storeSession(Session session);

  /// Clears the stored session
  Future<Result<void>> clearSession();

  /// Refreshes the current session
  Future<Result<Session>> refreshSession(Session session);
}

/// Simple local implementation of AuthRepository for demo purposes.
///
/// Uses admin:admin credentials for authentication.
class LocalAuthRepository implements AuthRepository {
  Session? _storedSession;

  @override
  Future<Result<Session>> login(Credentials credentials) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Simple admin:admin check
    if (credentials.username == 'admin' && credentials.password == 'admin') {
      final session = Session(
        user: User(
          id: 'local-user-1',
          username: credentials.username,
          displayName: 'Admin User',
        ),
        token: 'local-token-${DateTime.now().millisecondsSinceEpoch}',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      _storedSession = session;
      return Success(session);
    }

    return const Failure(AuthFailure(message: 'Invalid username or password'));
  }

  @override
  Future<Result<void>> logout() async {
    _storedSession = null;
    return const Success(null);
  }

  @override
  Future<Result<Session?>> getStoredSession() async => Success(_storedSession);

  @override
  Future<Result<void>> storeSession(Session session) async {
    _storedSession = session;
    return const Success(null);
  }

  @override
  Future<Result<void>> clearSession() async {
    _storedSession = null;
    return const Success(null);
  }

  @override
  Future<Result<Session>> refreshSession(Session session) async {
    if (session.isExpired) {
      return const Failure(AuthFailure(message: 'Session expired'));
    }

    final refreshed = session.copyWith(
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      token: 'refreshed-token-${DateTime.now().millisecondsSinceEpoch}',
    );
    _storedSession = refreshed;
    return Success(refreshed);
  }
}

