class UserEntity {
  final String id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? profilePictureUrl;
  final List<String> roles;
  final DateTime createdAt;
  final DateTime? lastLogin;

  UserEntity({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.profilePictureUrl,
    this.roles = const [],
    required this.createdAt,
    this.lastLogin,
  });

  /// Create UserEntity from Keycloak userinfo response
  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['sub'] ?? json['id'] ?? '',
      username: json['preferred_username'] ?? json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['given_name'],
      lastName: json['family_name'],
      profilePictureUrl: json['picture'],
      roles: List<String>.from(json['roles'] ?? []),
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] * 1000)
          : DateTime.now(),
      lastLogin: json['last_login'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_login'] * 1000)
          : null,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profilePictureUrl': profilePictureUrl,
      'roles': roles,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLogin': lastLogin?.millisecondsSinceEpoch,
    };
  }

  /// Get full name
  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  /// Check if user has a specific role
  bool hasRole(String role) => roles.contains(role);

  @override
  String toString() => 'UserEntity(id: $id, username: $username, email: $email)';
}

