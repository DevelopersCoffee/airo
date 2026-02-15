import 'package:equatable/equatable.dart';

/// Member role within a group
enum MemberRole {
  owner('Owner'),
  admin('Admin'),
  member('Member');

  final String displayName;
  const MemberRole(this.displayName);
}

/// Group member entity
///
/// Represents a user's membership in a group with their role and preferences.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-017)
class GroupMember extends Equatable {
  final String id;
  final String groupId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? email;
  final String? phoneNumber;
  final MemberRole role;
  final String currencyCode;
  final bool isActive;
  final DateTime joinedAt;
  final DateTime? leftAt;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.email,
    this.phoneNumber,
    this.role = MemberRole.member,
    this.currencyCode = 'INR',
    this.isActive = true,
    required this.joinedAt,
    this.leftAt,
  });

  /// Check if member can manage group (owner or admin)
  bool get canManageGroup =>
      role == MemberRole.owner || role == MemberRole.admin;

  /// Check if this is the current user
  /// TODO: Implement with auth integration
  bool isCurrentUser(String currentUserId) => userId == currentUserId;

  /// Create a copy with updated fields
  GroupMember copyWith({
    String? id,
    String? groupId,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? email,
    String? phoneNumber,
    MemberRole? role,
    String? currencyCode,
    bool? isActive,
    DateTime? joinedAt,
    DateTime? leftAt,
  }) {
    return GroupMember(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      currencyCode: currencyCode ?? this.currencyCode,
      isActive: isActive ?? this.isActive,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        userId,
        displayName,
        avatarUrl,
        email,
        phoneNumber,
        role,
        currencyCode,
        isActive,
        joinedAt,
        leftAt,
      ];
}

