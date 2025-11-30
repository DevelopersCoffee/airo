import '../../utils/locale_settings.dart';

/// Extended user profile with preferences and settings
class UserProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final String? phoneNumber;
  final LocaleSettings localeSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? preferences;

  const UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.phoneNumber,
    this.localeSettings = const LocaleSettings(),
    required this.createdAt,
    required this.updatedAt,
    this.preferences,
  });

  /// Create a new profile with default Indian settings
  factory UserProfile.withDefaults({
    required String id,
    required String username,
    String? displayName,
    String? email,
  }) {
    final now = DateTime.now();
    return UserProfile(
      id: id,
      username: username,
      displayName: displayName ?? username,
      email: email,
      localeSettings: LocaleSettings.india,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get effective display name (fallback to username)
  String get effectiveDisplayName => displayName ?? username;

  /// Get currency symbol from locale settings
  String get currencySymbol => localeSettings.supportedCurrency.symbol;

  /// Get currency code from locale settings
  String get currencyCode => localeSettings.currency;

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? email,
    String? avatarUrl,
    String? phoneNumber,
    LocaleSettings? localeSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      localeSettings: localeSettings ?? this.localeSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'phoneNumber': phoneNumber,
      'localeSettings': localeSettings.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'preferences': preferences,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      localeSettings: json['localeSettings'] != null
          ? LocaleSettings.fromJson(
              json['localeSettings'] as Map<String, dynamic>,
            )
          : LocaleSettings.india,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserProfile(id: $id, username: $username, displayName: $displayName)';
  }
}

