import '../models/user.dart';

/// Authentication state.
sealed class AuthState {
  const AuthState();

  /// Initial/unknown state.
  factory AuthState.initial() = AuthInitial;

  /// Loading state.
  factory AuthState.loading() = AuthLoading;

  /// Authenticated state.
  factory AuthState.authenticated(User user, {String? token}) {
    return AuthAuthenticated(user: user, token: token);
  }

  /// Unauthenticated state.
  factory AuthState.unauthenticated({String? reason}) {
    return AuthUnauthenticated(reason: reason);
  }

  /// Check if authenticated.
  bool get isAuthenticated => this is AuthAuthenticated;

  /// Check if loading.
  bool get isLoading => this is AuthLoading;

  /// Get the current user if authenticated.
  User? get currentUser => switch (this) {
        AuthAuthenticated(user: final u) => u,
        _ => null,
      };
}

/// Initial authentication state (not yet determined).
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading authentication state.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Authenticated state with user.
class AuthAuthenticated extends AuthState {
  final User user;
  final String? token;
  final DateTime authenticatedAt;

  AuthAuthenticated({
    required this.user,
    this.token,
    DateTime? authenticatedAt,
  }) : authenticatedAt = authenticatedAt ?? DateTime.now();

  AuthAuthenticated copyWith({
    User? user,
    String? token,
    DateTime? authenticatedAt,
  }) {
    return AuthAuthenticated(
      user: user ?? this.user,
      token: token ?? this.token,
      authenticatedAt: authenticatedAt ?? this.authenticatedAt,
    );
  }
}

/// Unauthenticated state.
class AuthUnauthenticated extends AuthState {
  final String? reason;

  const AuthUnauthenticated({this.reason});
}

/// Credentials for login.
class LoginCredentials {
  final String username;
  final String password;
  final bool rememberMe;

  const LoginCredentials({
    required this.username,
    required this.password,
    this.rememberMe = false,
  });
}

/// Credentials for registration.
class RegisterCredentials {
  final String username;
  final String password;
  final String? email;
  final String? displayName;

  const RegisterCredentials({
    required this.username,
    required this.password,
    this.email,
    this.displayName,
  });
}

