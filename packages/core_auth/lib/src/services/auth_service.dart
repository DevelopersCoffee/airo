import 'dart:async';

import 'package:core_domain/core_domain.dart';

import '../models/credentials.dart';
import '../models/session.dart';
import '../repositories/auth_repository.dart';
import 'auth_state.dart';

/// Service for managing authentication
class AuthService {
  AuthService({
    required AuthRepository repository,
  }) : _repository = repository;

  final AuthRepository _repository;
  final _stateController = StreamController<AuthState>.broadcast();

  AuthState _state = const AuthInitial();

  /// Current authentication state
  AuthState get state => _state;

  /// Stream of authentication state changes
  Stream<AuthState> get stateStream => _stateController.stream;

  /// Attempts to login with the given credentials
  Future<Result<Session>> login(Credentials credentials) async {
    _updateState(const AuthLoading());

    if (!credentials.isValid) {
      _updateState(const AuthError('Invalid credentials'));
      return const Failure(
        ValidationFailure(message: 'Username and password are required'),
      );
    }

    final result = await _repository.login(credentials);

    result.fold(
      onSuccess: (session) => _updateState(Authenticated(session)),
      onFailure: (failure) => _updateState(AuthError(failure.message)),
    );

    return result;
  }

  /// Logs out the current user
  Future<Result<void>> logout() async {
    _updateState(const AuthLoading());

    final result = await _repository.logout();

    result.fold(
      onSuccess: (_) => _updateState(const Unauthenticated()),
      onFailure: (failure) {
        // Still log out locally even if server fails
        _updateState(const Unauthenticated());
      },
    );

    return result;
  }

  /// Checks if there's an existing session
  Future<void> checkSession() async {
    _updateState(const AuthLoading());

    final result = await _repository.getStoredSession();

    result.fold(
      onSuccess: (session) {
        if (session != null && session.isValid) {
          _updateState(Authenticated(session));
        } else {
          _updateState(const Unauthenticated());
        }
      },
      onFailure: (_) => _updateState(const Unauthenticated()),
    );
  }

  void _updateState(AuthState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Disposes of resources
  Future<void> dispose() async {
    await _stateController.close();
  }
}

