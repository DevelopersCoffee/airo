import 'package:meta/meta.dart';

import 'entity.dart';

/// User entity representing an authenticated user in the system.
@immutable
class User extends Entity {
  const User({
    required super.id,
    required this.username,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.createdAt,
  });

  /// Username for authentication
  final String username;

  /// Display name shown in UI
  final String? displayName;

  /// Email address (optional)
  final String? email;

  /// URL to user's avatar image
  final String? avatarUrl;

  /// When the user account was created
  final DateTime? createdAt;

  /// Returns the display name or falls back to username
  String get name => displayName ?? username;

  @override
  List<Object?> get props => [
        ...super.props,
        username,
        displayName,
        email,
        avatarUrl,
        createdAt,
      ];

  /// Creates a copy of this user with the given fields replaced
  User copyWith({
    String? id,
    String? username,
    String? displayName,
    String? email,
    String? avatarUrl,
    DateTime? createdAt,
  }) =>
      User(
        id: id ?? this.id,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt ?? this.createdAt,
      );
}

