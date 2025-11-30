import 'package:core_auth/core_auth.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalAuthRepository', () {
    late LocalAuthRepository repository;

    setUp(() {
      repository = LocalAuthRepository();
    });

    test('login with valid credentials returns session', () async {
      const credentials = Credentials(username: 'admin', password: 'admin');
      final result = await repository.login(credentials);

      expect(result.isSuccess, isTrue);
      expect(result.value.user.username, 'admin');
      expect(result.value.token, isNotEmpty);
    });

    test('login with invalid credentials returns failure', () async {
      const credentials = Credentials(username: 'wrong', password: 'wrong');
      final result = await repository.login(credentials);

      expect(result.isFailure, isTrue);
    });

    test('logout clears session', () async {
      const credentials = Credentials(username: 'admin', password: 'admin');
      await repository.login(credentials);
      await repository.logout();

      final storedSession = await repository.getStoredSession();
      expect(storedSession.value, isNull);
    });

    test('getStoredSession returns session after login', () async {
      const credentials = Credentials(username: 'admin', password: 'admin');
      await repository.login(credentials);

      final result = await repository.getStoredSession();
      expect(result.isSuccess, isTrue);
      expect(result.value, isNotNull);
      expect(result.value!.user.username, 'admin');
    });

    test('refreshSession returns new session', () async {
      const credentials = Credentials(username: 'admin', password: 'admin');
      final loginResult = await repository.login(credentials);
      final originalSession = loginResult.value;

      final refreshResult = await repository.refreshSession(originalSession);
      expect(refreshResult.isSuccess, isTrue);
      expect(refreshResult.value.token, isNot(equals(originalSession.token)));
    });
  });

  group('Credentials', () {
    test('isValid returns true for non-empty values', () {
      const credentials = Credentials(username: 'user', password: 'pass');
      expect(credentials.isValid, isTrue);
    });

    test('isValid returns false for empty username', () {
      const credentials = Credentials(username: '', password: 'pass');
      expect(credentials.isValid, isFalse);
    });

    test('isValid returns false for empty password', () {
      const credentials = Credentials(username: 'user', password: '');
      expect(credentials.isValid, isFalse);
    });

    test('equality works correctly', () {
      const cred1 = Credentials(username: 'user', password: 'pass');
      const cred2 = Credentials(username: 'user', password: 'pass');
      const cred3 = Credentials(username: 'other', password: 'pass');

      expect(cred1, equals(cred2));
      expect(cred1, isNot(equals(cred3)));
    });
  });

  group('Session', () {
    test('isValid returns true for non-expired session', () {
      final session = Session(
        user: const User(id: '1', username: 'test'),
        token: 'token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      expect(session.isValid, isTrue);
      expect(session.isExpired, isFalse);
    });

    test('isExpired returns true for expired session', () {
      final session = Session(
        user: const User(id: '1', username: 'test'),
        token: 'token',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(session.isExpired, isTrue);
      expect(session.isValid, isFalse);
    });

    test('copyWith creates new session with updated fields', () {
      final original = Session(
        user: const User(id: '1', username: 'test'),
        token: 'token1',
        expiresAt: DateTime.now(),
      );

      final updated = original.copyWith(token: 'token2');

      expect(updated.token, 'token2');
      expect(updated.user, original.user);
    });
  });

  group('AuthState', () {
    test('AuthInitial is not authenticated', () {
      const state = AuthInitial();
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.session, isNull);
    });

    test('AuthLoading indicates loading state', () {
      const state = AuthLoading();
      expect(state.isLoading, isTrue);
      expect(state.isAuthenticated, isFalse);
    });

    test('Authenticated provides session', () {
      final session = Session(
        user: const User(id: '1', username: 'test'),
        token: 'token',
      );
      final state = Authenticated(session);

      expect(state.isAuthenticated, isTrue);
      expect(state.session, session);
    });

    test('Unauthenticated with message', () {
      const state = Unauthenticated(message: 'Session expired');
      expect(state.isAuthenticated, isFalse);
      expect(state.message, 'Session expired');
    });

    test('AuthError contains error message', () {
      const state = AuthError('Login failed');
      expect(state.isAuthenticated, isFalse);
      expect(state.message, 'Login failed');
    });
  });
}

