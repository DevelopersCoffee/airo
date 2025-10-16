import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../models/user_entity.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserEntity? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserEntity? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize auth state on app startup
  Future<void> initializeAuth() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final isAuth = await _authService.isAuthenticated();
      _isAuthenticated = isAuth;

      if (isAuth) {
        await _loadUserInfo();
      }
    } catch (e) {
      _error = 'Failed to initialize authentication: $e';
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Authenticate user with Keycloak
  Future<bool> authenticate() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.authenticate();
      if (success) {
        _isAuthenticated = true;
        await _loadUserInfo();
        return true;
      } else {
        _error = 'Authentication failed';
        _isAuthenticated = false;
        return false;
      }
    } catch (e) {
      _error = 'Authentication error: $e';
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load user information from Keycloak
  Future<void> _loadUserInfo() async {
    try {
      _user = await _authService.getUserInfo();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load user info: $e';
      _user = null;
    }
  }

  /// Logout user
  Future<bool> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.logout();
      if (success) {
        _isAuthenticated = false;
        _user = null;
      }
      return success;
    } catch (e) {
      _error = 'Logout error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh user information
  Future<void> refreshUserInfo() async {
    try {
      await _loadUserInfo();
    } catch (e) {
      _error = 'Failed to refresh user info: $e';
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

