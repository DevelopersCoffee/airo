import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User', () {
    test('should create user with required fields', () {
      const user = User(
        id: '123',
        username: 'testuser',
      );

      expect(user.id, '123');
      expect(user.username, 'testuser');
      expect(user.displayName, isNull);
      expect(user.email, isNull);
    });

    test('should create user with all fields', () {
      final now = DateTime.now();
      final user = User(
        id: '123',
        username: 'testuser',
        displayName: 'Test User',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/avatar.png',
        createdAt: now,
      );

      expect(user.id, '123');
      expect(user.username, 'testuser');
      expect(user.displayName, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
      expect(user.createdAt, now);
    });

    test('name should return displayName when available', () {
      const user = User(
        id: '123',
        username: 'testuser',
        displayName: 'Test User',
      );

      expect(user.name, 'Test User');
    });

    test('name should return username when displayName is null', () {
      const user = User(
        id: '123',
        username: 'testuser',
      );

      expect(user.name, 'testuser');
    });

    test('copyWith should create new user with updated fields', () {
      const original = User(
        id: '123',
        username: 'testuser',
      );

      final updated = original.copyWith(
        displayName: 'Updated Name',
        email: 'new@example.com',
      );

      expect(updated.id, '123');
      expect(updated.username, 'testuser');
      expect(updated.displayName, 'Updated Name');
      expect(updated.email, 'new@example.com');
    });

    test('equality should be based on all props', () {
      const user1 = User(id: '123', username: 'testuser');
      const user2 = User(id: '123', username: 'testuser');
      const user3 = User(id: '456', username: 'testuser');

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
    });
  });
}

