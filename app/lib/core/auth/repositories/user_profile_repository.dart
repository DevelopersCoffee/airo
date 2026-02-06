import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/result.dart';
import '../../utils/locale_settings.dart';
import '../models/user_profile.dart';

/// Repository interface for user profile management
abstract interface class UserProfileRepository {
  /// Get current user's profile
  Future<Result<UserProfile?>> getCurrentProfile();

  /// Save user profile
  Future<Result<UserProfile>> saveProfile(UserProfile profile);

  /// Update profile fields
  Future<Result<UserProfile>> updateProfile({
    String? displayName,
    String? email,
    String? avatarUrl,
    String? phoneNumber,
    LocaleSettings? localeSettings,
    Map<String, dynamic>? preferences,
  });

  /// Delete profile (for logout/account deletion)
  Future<Result<void>> deleteProfile();

  /// Check if profile exists for current user
  Future<bool> hasProfile();
}

/// Local storage implementation of UserProfileRepository
/// Uses SharedPreferences for non-sensitive data
/// TODO: Use flutter_secure_storage for sensitive fields in production
class LocalUserProfileRepository implements UserProfileRepository {
  static const String _profileKey = 'airo_user_profile';
  static const String _currentUserIdKey = 'airo_current_user_id';

  SharedPreferences? _prefs;
  UserProfile? _cachedProfile;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get storage key for specific user
  Future<String> get _userProfileKey async {
    final prefs = await _preferences;
    final userId = prefs.getString(_currentUserIdKey) ?? 'default';
    return '${_profileKey}_$userId';
  }

  @override
  Future<Result<UserProfile?>> getCurrentProfile() async {
    try {
      if (_cachedProfile != null) {
        return Ok(_cachedProfile);
      }

      final prefs = await _preferences;
      final key = await _userProfileKey;
      final jsonStr = prefs.getString(key);

      if (jsonStr == null) {
        return const Ok(null);
      }

      final profile = UserProfile.fromJson(jsonDecode(jsonStr));
      _cachedProfile = profile;
      return Ok(profile);
    } catch (e, s) {
      debugPrint('Error loading profile: $e');
      return Err(e, s);
    }
  }

  @override
  Future<Result<UserProfile>> saveProfile(UserProfile profile) async {
    try {
      final prefs = await _preferences;
      final key = await _userProfileKey;

      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      await prefs.setString(key, jsonEncode(updatedProfile.toJson()));
      _cachedProfile = updatedProfile;

      return Ok(updatedProfile);
    } catch (e, s) {
      debugPrint('Error saving profile: $e');
      return Err(e, s);
    }
  }

  @override
  Future<Result<UserProfile>> updateProfile({
    String? displayName,
    String? email,
    String? avatarUrl,
    String? phoneNumber,
    LocaleSettings? localeSettings,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final currentResult = await getCurrentProfile();
      final current = currentResult.getOrNull();

      if (current == null) {
        return Err(Exception('No profile found to update'), StackTrace.current);
      }

      final updated = current.copyWith(
        displayName: displayName ?? current.displayName,
        email: email ?? current.email,
        avatarUrl: avatarUrl ?? current.avatarUrl,
        phoneNumber: phoneNumber ?? current.phoneNumber,
        localeSettings: localeSettings ?? current.localeSettings,
        preferences: preferences ?? current.preferences,
        updatedAt: DateTime.now(),
      );

      return saveProfile(updated);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<Result<void>> deleteProfile() async {
    try {
      final prefs = await _preferences;
      final key = await _userProfileKey;
      await prefs.remove(key);
      _cachedProfile = null;
      return const Ok(null);
    } catch (e, s) {
      return Err(e, s);
    }
  }

  @override
  Future<bool> hasProfile() async {
    final result = await getCurrentProfile();
    return result.getOrNull() != null;
  }

  /// Invalidate cache (call on user switch)
  void invalidateCache() {
    _cachedProfile = null;
  }
}

/// Provider for user profile repository
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return LocalUserProfileRepository();
});

/// Provider for current user profile (async)
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.watch(userProfileRepositoryProvider);
  final result = await repo.getCurrentProfile();
  return result.getOrNull();
});
