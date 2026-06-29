import '../../domain/entities/group_member.dart';
import '../../domain/repositories/group_repository.dart';

typedef Result<T> = ({T? data, String? error});

class AddGroupMemberUseCase {
  final GroupRepository _repository;

  AddGroupMemberUseCase(this._repository);

  Future<Result<GroupMember>> execute(AddGroupMemberParams params) async {
    final name = params.displayName.trim();
    if (params.groupId.isEmpty) {
      return (data: null, error: 'Group is required');
    }
    if (name.isEmpty) {
      return (data: null, error: 'Member name is required');
    }

    final now = DateTime.now();
    final userId = params.userId ?? _slugForName(name);
    final member = GroupMember(
      id: _generateMemberId(),
      groupId: params.groupId,
      userId: userId,
      displayName: name,
      email: params.email,
      phoneNumber: params.phoneNumber,
      currencyCode: params.currencyCode,
      role: MemberRole.member,
      joinedAt: now,
    );

    return _repository.addMember(member);
  }

  String _generateMemberId() {
    return 'member_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _slugForName(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? _generateMemberId() : slug;
  }
}

class AddGroupMemberParams {
  final String groupId;
  final String displayName;
  final String? userId;
  final String? email;
  final String? phoneNumber;
  final String currencyCode;

  const AddGroupMemberParams({
    required this.groupId,
    required this.displayName,
    this.userId,
    this.email,
    this.phoneNumber,
    this.currencyCode = 'INR',
  });
}
