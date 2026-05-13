import 'package:airo_app/features/coins/application/use_cases/add_group_member_use_case.dart';
import 'package:airo_app/features/coins/domain/entities/group_member.dart';
import 'package:airo_app/features/coins/domain/repositories/group_repository.dart'
    hide Result;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddGroupMemberUseCase', () {
    test('creates an active member with the selected user currency', () async {
      final repository = _FakeGroupRepository();
      final useCase = AddGroupMemberUseCase(repository);

      final result = await useCase.execute(
        const AddGroupMemberParams(
          groupId: 'group_1',
          displayName: 'Rahul',
          currencyCode: 'USD',
        ),
      );

      expect(result.error, isNull);
      expect(result.data!.groupId, 'group_1');
      expect(result.data!.displayName, 'Rahul');
      expect(result.data!.currencyCode, 'USD');
      expect(result.data!.role, MemberRole.member);
      expect(repository.addedMember, result.data);
    });

    test('rejects blank member names', () async {
      final useCase = AddGroupMemberUseCase(_FakeGroupRepository());

      final result = await useCase.execute(
        const AddGroupMemberParams(groupId: 'group_1', displayName: ' '),
      );

      expect(result.data, isNull);
      expect(result.error, 'Member name is required');
    });
  });
}

class _FakeGroupRepository implements GroupRepository {
  GroupMember? addedMember;

  @override
  Future<Result<GroupMember>> addMember(GroupMember member) async {
    addedMember = member;
    return (data: member, error: null);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
