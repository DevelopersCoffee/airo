import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication service for the super app
class AuthService {
  static const String _keyCurrentUser = 'current_user';
  static const String _keyUsers = 'registered_users';
  static const String _keyIsLoggedIn = 'is_logged_in';

  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  SharedPreferences? _prefs;

  /// Initialize the auth service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if user is currently logged in
  bool get isLoggedIn {
    return _prefs?.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Get current user
  User? get currentUser {
    final userJson = _prefs?.getString(_keyCurrentUser);
    if (userJson != null) {
      try {
        return User.fromJson(jsonDecode(userJson));
      } catch (e) {
        debugPrint('Error parsing current user: $e');
      }
    }
    return null;
  }

  /// Login with username and password
  Future<AuthResult> login(String username, String password) async {
    try {
      if (username.trim().isEmpty || password.trim().isEmpty) {
        return AuthResult.failure('Username and password are required');
      }

      // Check for admin login
      if (username.toLowerCase() == 'admin' && password == 'admin') {
        final adminUser = User(
          id: 'admin',
          username: 'admin',
          isAdmin: true,
          createdAt: DateTime.now(),
        );

        await _setCurrentUser(adminUser);
        return AuthResult.success(adminUser);
      }

      // Check registered users
      final users = await _getRegisteredUsers();
      final user = users.firstWhere(
        (u) => u.username.toLowerCase() == username.toLowerCase(),
        orElse: () => throw Exception('User not found'),
      );

      // Simple password check (in production, use proper hashing)
      if (user.password != password) {
        return AuthResult.failure('Invalid password');
      }

      await _setCurrentUser(user);
      return AuthResult.success(user);
    } catch (e) {
      return AuthResult.failure('Invalid username or password');
    }
  }

  /// Register a new user
  Future<AuthResult> register(String username, String password) async {
    try {
      if (username.trim().isEmpty || password.trim().isEmpty) {
        return AuthResult.failure('Username and password are required');
      }

      if (username.length < 3) {
        return AuthResult.failure('Username must be at least 3 characters');
      }

      if (password.length < 4) {
        return AuthResult.failure('Password must be at least 4 characters');
      }

      // Check if username already exists
      final users = await _getRegisteredUsers();
      if (users.any(
            (u) => u.username.toLowerCase() == username.toLowerCase(),
          ) ||
          username.toLowerCase() == 'admin') {
        return AuthResult.failure('Username already exists');
      }

      // Create new user
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: username.trim(),
        password: password, // In production, hash this
        isAdmin: false,
        createdAt: DateTime.now(),
      );

      // Save user
      users.add(newUser);
      await _saveRegisteredUsers(users);

      // Auto-login after registration
      await _setCurrentUser(newUser);
      return AuthResult.success(newUser);
    } catch (e) {
      return AuthResult.failure('Registration failed: ${e.toString()}');
    }
  }

  /// Logout current user
  Future<void> logout() async {
    await _prefs?.remove(_keyCurrentUser);
    await _prefs?.setBool(_keyIsLoggedIn, false);
  }

  /// Get all registered users (admin only)
  Future<List<User>> getRegisteredUsers() async {
    if (currentUser?.isAdmin != true) {
      throw Exception('Admin access required');
    }
    return _getRegisteredUsers();
  }

  /// Delete a user (admin only)
  Future<bool> deleteUser(String userId) async {
    if (currentUser?.isAdmin != true) {
      return false;
    }

    final users = await _getRegisteredUsers();
    users.removeWhere((u) => u.id == userId);
    await _saveRegisteredUsers(users);
    return true;
  }

  /// Private methods
  Future<List<User>> _getRegisteredUsers() async {
    final usersJson = _prefs?.getString(_keyUsers);
    if (usersJson != null) {
      try {
        final List<dynamic> usersList = jsonDecode(usersJson);
        return usersList.map((json) => User.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Error parsing users: $e');
      }
    }
    return [];
  }

  Future<void> _saveRegisteredUsers(List<User> users) async {
    final usersJson = jsonEncode(users.map((u) => u.toJson()).toList());
    await _prefs?.setString(_keyUsers, usersJson);
  }

  Future<void> _setCurrentUser(User user) async {
    await _prefs?.setString(_keyCurrentUser, jsonEncode(user.toJson()));
    await _prefs?.setBool(_keyIsLoggedIn, true);
  }
}

/// User model
class User {
  final String id;
  final String username;
  final String? password; // Only stored for demo purposes
  final bool isAdmin;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
    this.password,
    required this.isAdmin,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'isAdmin': isAdmin,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      password: json['password'],
      isAdmin: json['isAdmin'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? password,
    bool? isAdmin,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, isAdmin: $isAdmin)';
  }
}

/// Authentication result
class AuthResult {
  final bool success;
  final String? message;
  final User? user;

  const AuthResult._({required this.success, this.message, this.user});

  factory AuthResult.success(User user) {
    return AuthResult._(success: true, user: user);
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(success: false, message: message);
  }
}
