import 'package:equatable/equatable.dart';
import 'group_member.dart';

/// Group settings configuration
class GroupSettings extends Equatable {
  final bool simplifyDebts;
  final bool defaultEqualSplit;
  final bool allowMultiCurrency;
  final String defaultCurrencyCode;

  const GroupSettings({
    this.simplifyDebts = true,
    this.defaultEqualSplit = true,
    this.allowMultiCurrency = false,
    this.defaultCurrencyCode = 'INR',
  });

  @override
  List<Object?> get props => [
        simplifyDebts,
        defaultEqualSplit,
        allowMultiCurrency,
        defaultCurrencyCode,
      ];
}

/// Group entity for split bill management
///
/// Represents a group of people sharing expenses (e.g., roommates, trip group).
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-017)
class Group extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String defaultCurrencyCode;
  final List<GroupMember> members;
  final GroupSettings settings;
  final String creatorId;
  final String? inviteCode;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.defaultCurrencyCode = 'INR',
    this.members = const [],
    this.settings = const GroupSettings(),
    required this.creatorId,
    this.inviteCode,
    this.isArchived = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if group has members with different currencies
  bool get isMultiCurrency =>
      members.any((m) => m.currencyCode != defaultCurrencyCode);

  /// Get member count
  int get memberCount => members.length;

  /// Check if a user is a member
  bool isMember(String userId) => members.any((m) => m.userId == userId);

  /// Get member by user ID
  GroupMember? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  /// Create a copy with updated fields
  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    String? defaultCurrencyCode,
    List<GroupMember>? members,
    GroupSettings? settings,
    String? creatorId,
    String? inviteCode,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      defaultCurrencyCode: defaultCurrencyCode ?? this.defaultCurrencyCode,
      members: members ?? this.members,
      settings: settings ?? this.settings,
      creatorId: creatorId ?? this.creatorId,
      inviteCode: inviteCode ?? this.inviteCode,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        iconUrl,
        defaultCurrencyCode,
        members,
        settings,
        creatorId,
        inviteCode,
        isArchived,
        createdAt,
        updatedAt,
      ];
}

