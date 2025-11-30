import 'package:meta/meta.dart';

import '../models/session.dart';

/// Represents the current authentication state
@immutable
sealed class AuthState {
  const AuthState();

  /// Whether the user is authenticated
  bool get isAuthenticated => this is Authenticated;

  /// Whether authentication is in progress
  bool get isLoading => this is AuthLoading;

  /// Gets the session if authenticated, null otherwise
  Session? get session => switch (this) {
        Authenticated(:final session) => session,
        _ => null,
      };
}

/// Initial state before any auth check
@immutable
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Authentication is in progress
@immutable
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is authenticated with a valid session
@immutable
class Authenticated extends AuthState {
  const Authenticated(this.session);

  final Session session;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Authenticated && other.session == session;

  @override
  int get hashCode => session.hashCode;
}

/// User is not authenticated
@immutable
class Unauthenticated extends AuthState {
  const Unauthenticated({this.message});

  /// Optional message explaining why unauthenticated
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unauthenticated && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// Authentication failed with an error
@immutable
class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

