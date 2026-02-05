import 'package:flutter_test/flutter_test.dart';
import 'package:core_auth/core_auth.dart';

void main() {
  group('User (core_auth)', () {
    test('can be created with required fields', () {
      final user = User(
        id: '123',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(user.id, '123');
      expect(user.username, 'testuser');
      expect(user.isAdmin, isFalse);
    });

    test('name returns displayName if set', () {
      final user = User(
        id: '123',
        username: 'testuser',
        displayName: 'Test User',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(user.name, 'Test User');
    });

    test('name returns username if displayName not set', () {
      final user = User(
        id: '123',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(user.name, 'testuser');
    });

    test('hasRole returns true for admin role when isAdmin', () {
      final user = User(
        id: '123',
        username: 'admin',
        isAdmin: true,
        createdAt: DateTime(2024, 1, 1),
      );
      expect(user.hasRole('admin'), isTrue);
    });

    test('toJson and fromJson roundtrip', () {
      final user = User(
        id: '123',
        username: 'testuser',
        email: 'test@example.com',
        isAdmin: true,
        createdAt: DateTime(2024, 1, 1),
      );
      final json = user.toJson();
      final restored = User.fromJson(json);
      expect(restored.id, user.id);
      expect(restored.username, user.username);
      expect(restored.email, user.email);
      expect(restored.isAdmin, user.isAdmin);
    });

    test('copyWith creates modified copy', () {
      final user = User(
        id: '123',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
      );
      final modified = user.copyWith(displayName: 'New Name');
      expect(modified.displayName, 'New Name');
      expect(modified.id, user.id);
    });

    test('equality is based on id', () {
      final user1 = User(
        id: '123',
        username: 'user1',
        createdAt: DateTime(2024, 1, 1),
      );
      final user2 = User(
        id: '123',
        username: 'user2',
        createdAt: DateTime(2024, 1, 2),
      );
      expect(user1, equals(user2));
    });
  });

  group('AuthResult', () {
    test('success creates AuthSuccess', () {
      final user = User(
        id: '123',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
      );
      final result = AuthResult.success(user);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.userOrNull, user);
    });

    test('failure creates AuthFailure', () {
      final result = AuthResult.failure('Invalid credentials');
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, 'Invalid credentials');
    });

    test('success with token', () {
      final user = User(
        id: '123',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
      );
      final result = AuthResult.success(user, token: 'abc123');
      expect(result, isA<AuthSuccess>());
      expect((result as AuthSuccess).token, 'abc123');
    });
  });

  group('AuthState (services)', () {
    test('AuthInitial is not authenticated', () {
      const state = AuthInitial();
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
    });

    test('AuthLoading indicates loading state', () {
      const state = AuthLoading();
      expect(state.isLoading, isTrue);
      expect(state.isAuthenticated, isFalse);
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

  group('Credentials', () {
    test('can be created', () {
      const creds = Credentials(username: 'testuser', password: 'password123');
      expect(creds.username, 'testuser');
      expect(creds.password, 'password123');
    });

    test('isValid returns true for non-empty values', () {
      const creds = Credentials(username: 'user', password: 'pass');
      expect(creds.isValid, isTrue);
    });

    test('isValid returns false for empty username', () {
      const creds = Credentials(username: '', password: 'pass');
      expect(creds.isValid, isFalse);
    });

    test('isValid returns false for empty password', () {
      const creds = Credentials(username: 'user', password: '');
      expect(creds.isValid, isFalse);
    });
  });

  group('AuthErrorCode', () {
    test('has human-readable messages', () {
      expect(
        AuthErrorCode.invalidCredentials.message,
        'Invalid username or password',
      );
      expect(AuthErrorCode.userNotFound.message, 'User not found');
      expect(AuthErrorCode.tokenExpired.message, contains('expired'));
    });
  });
}
