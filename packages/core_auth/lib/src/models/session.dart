import 'package:core_domain/core_domain.dart';
import 'package:meta/meta.dart';

/// Represents an authenticated user session
@immutable
class Session {
  const Session({
    required this.user,
    required this.token,
    this.expiresAt,
    this.refreshToken,
  });

  /// The authenticated user
  final User user;

  /// Authentication token
  final String token;

  /// When the session expires
  final DateTime? expiresAt;

  /// Token for refreshing the session
  final String? refreshToken;

  /// Whether the session has expired
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Whether the session is valid
  bool get isValid => !isExpired && token.isNotEmpty;

  /// Creates a copy with updated fields
  Session copyWith({
    User? user,
    String? token,
    DateTime? expiresAt,
    String? refreshToken,
  }) =>
      Session(
        user: user ?? this.user,
        token: token ?? this.token,
        expiresAt: expiresAt ?? this.expiresAt,
        refreshToken: refreshToken ?? this.refreshToken,
      );

  @override
  String toString() => 'Session(user: ${user.username}, valid: $isValid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          other.user == user &&
          other.token == token &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(user, token, expiresAt);
}

