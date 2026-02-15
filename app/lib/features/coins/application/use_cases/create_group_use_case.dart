import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/repositories/group_repository.dart';

/// Result type for use case operations
typedef Result<T> = ({T? data, String? error});

/// Use case for creating a new group
///
/// Creates a group and adds the creator as admin member.
///
/// Phase: 2 (Split Engine)
/// See: docs/features/coins/ENGINEERING_TICKETS_PHASE_2.md (COINS-019)
class CreateGroupUseCase {
  final GroupRepository _repository;

  CreateGroupUseCase(this._repository);

  /// Execute the use case
  Future<Result<Group>> execute(CreateGroupParams params) async {
    // Validate
    if (params.name.trim().isEmpty) {
      return (data: null, error: 'Group name is required');
    }

    if (params.name.trim().length < 2) {
      return (data: null, error: 'Group name must be at least 2 characters');
    }

    if (params.creatorId.isEmpty) {
      return (data: null, error: 'Creator ID is required');
    }

    final now = DateTime.now();

    // Create creator as admin member
    final creatorMember = GroupMember(
      id: _generateMemberId(),
      groupId: '', // Will be set after group creation
      userId: params.creatorId,
      displayName: params.creatorDisplayName ?? 'You',
      role: MemberRole.admin,
      currencyCode: params.defaultCurrencyCode,
      joinedAt: now,
    );

    // Create the group
    final group = Group(
      id: _generateGroupId(),
      name: params.name.trim(),
      description: params.description,
      iconUrl: params.iconUrl,
      defaultCurrencyCode: params.defaultCurrencyCode,
      members: [creatorMember.copyWith(groupId: _generateGroupId())],
      settings: params.settings ?? const GroupSettings(),
      creatorId: params.creatorId,
      createdAt: now,
      isArchived: false,
    );

    return _repository.create(group);
  }

  String _generateGroupId() {
    return 'group_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateMemberId() {
    return 'member_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Parameters for creating a group
class CreateGroupParams {
  final String name;
  final String? description;
  final String? iconUrl;
  final String defaultCurrencyCode;
  final String creatorId;
  final String? creatorDisplayName;
  final GroupSettings? settings;

  const CreateGroupParams({
    required this.name,
    this.description,
    this.iconUrl,
    this.defaultCurrencyCode = 'INR',
    required this.creatorId,
    this.creatorDisplayName,
    this.settings,
  });
}

