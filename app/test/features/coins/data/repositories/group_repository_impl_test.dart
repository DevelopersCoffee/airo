import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:airo_app/features/coins/data/datasources/coins_local_datasource.dart';
import 'package:airo_app/features/coins/data/mappers/group_mapper.dart';
import 'package:airo_app/features/coins/data/repositories/group_repository_impl.dart';
import 'package:airo_app/features/coins/domain/entities/group.dart';
import 'package:airo_app/features/coins/domain/entities/group_member.dart';

class MockCoinsLocalDatasource extends Mock implements CoinsLocalDatasource {}

class MockGroupMapper extends Mock implements GroupMapper {}

void main() {
  late MockCoinsLocalDatasource mockDatasource;
  late MockGroupMapper mockMapper;
  late GroupRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockCoinsLocalDatasource();
    mockMapper = MockGroupMapper();
    repository = GroupRepositoryImpl(mockDatasource, mockMapper);
  });

  setUpAll(() {
    registerFallbackValue(_createGroupEntity());
    registerFallbackValue(_createGroup());
    registerFallbackValue(_createGroupMemberEntity());
    registerFallbackValue(_createGroupMember());
  });

  group('GroupRepositoryImpl', () {
    // ==================== Group Operations ====================
    group('findById', () {
      test('should return group when found', () async {
        final entity = _createGroupEntity();
        final group = _createGroup();

        when(
          () => mockDatasource.getGroupById('grp1'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(group);

        final result = await repository.findById('grp1');

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        expect(result.data!.id, 'grp1');
        verify(() => mockDatasource.getGroupById('grp1')).called(1);
      });

      test('should return error when not found', () async {
        when(
          () => mockDatasource.getGroupById('nonexistent'),
        ).thenAnswer((_) async => null);

        final result = await repository.findById('nonexistent');

        expect(result.data, isNull);
        expect(result.error, 'Group not found');
      });

      test('should return error on exception', () async {
        when(
          () => mockDatasource.getGroupById(any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.findById('grp1');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to fetch group'));
      });
    });

    group('findByInviteCode', () {
      test('should return group when invite code matches', () async {
        final entity = _createGroupEntity(inviteCode: 'ABC123');
        final group = _createGroup(inviteCode: 'ABC123');

        when(
          () => mockDatasource.getGroupByInviteCode('ABC123'),
        ).thenAnswer((_) async => entity);
        when(() => mockMapper.toDomain(entity)).thenReturn(group);

        final result = await repository.findByInviteCode('ABC123');

        expect(result.data, isNotNull);
        expect(result.data!.inviteCode, 'ABC123');
        expect(result.error, isNull);
      });

      test('should return null when invite code not found', () async {
        when(
          () => mockDatasource.getGroupByInviteCode('INVALID'),
        ).thenAnswer((_) async => null);

        final result = await repository.findByInviteCode('INVALID');

        expect(result.data, isNull);
        expect(result.error, isNull);
      });

      test('should return error on exception', () async {
        when(
          () => mockDatasource.getGroupByInviteCode(any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.findByInviteCode('ABC123');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to fetch group'));
      });
    });

    group('findAll', () {
      test('should return all groups', () async {
        final entities = [_createGroupEntity(), _createGroupEntity(id: 'grp2')];
        final group = _createGroup();

        when(
          () => mockDatasource.getAllGroups(),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(group);

        final result = await repository.findAll();

        expect(result.data, isNotNull);
        expect(result.data!.length, 2);
        expect(result.error, isNull);
      });

      test('should return empty list when no groups', () async {
        when(() => mockDatasource.getAllGroups()).thenAnswer((_) async => []);

        final result = await repository.findAll();

        expect(result.data, isNotNull);
        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });
    });

    group('findActive', () {
      test('should return only active groups', () async {
        final entities = [_createGroupEntity()];
        final group = _createGroup();

        when(
          () => mockDatasource.getActiveGroups(),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.toDomain(any())).thenReturn(group);

        final result = await repository.findActive();

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });
    });

    group('create', () {
      test('should create group successfully', () async {
        final group = _createGroup();
        final entity = _createGroupEntity();

        when(() => mockMapper.toEntity(group)).thenReturn(entity);
        when(() => mockDatasource.insertGroup(any())).thenAnswer((_) async {});

        final result = await repository.create(group);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        verify(() => mockDatasource.insertGroup(entity)).called(1);
      });

      test('should return error on create failure', () async {
        final group = _createGroup();

        when(() => mockMapper.toEntity(any())).thenReturn(_createGroupEntity());
        when(
          () => mockDatasource.insertGroup(any()),
        ).thenThrow(Exception('Insert failed'));

        final result = await repository.create(group);

        expect(result.data, isNull);
        expect(result.error, contains('Failed to create group'));
      });
    });

    group('update', () {
      test('should update group successfully', () async {
        final group = _createGroup();
        final entity = _createGroupEntity();

        when(() => mockMapper.toEntity(group)).thenReturn(entity);
        when(() => mockDatasource.updateGroup(any())).thenAnswer((_) async {});

        final result = await repository.update(group);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });

      test('should return error on update failure', () async {
        final group = _createGroup();

        when(() => mockMapper.toEntity(any())).thenReturn(_createGroupEntity());
        when(
          () => mockDatasource.updateGroup(any()),
        ).thenThrow(Exception('Update failed'));

        final result = await repository.update(group);

        expect(result.data, isNull);
        expect(result.error, contains('Failed to update group'));
      });
    });

    group('archive', () {
      test('should archive group successfully', () async {
        when(
          () => mockDatasource.archiveGroup('grp1'),
        ).thenAnswer((_) async {});

        final result = await repository.archive('grp1');

        expect(result.error, isNull);
        verify(() => mockDatasource.archiveGroup('grp1')).called(1);
      });

      test('should return error on archive failure', () async {
        when(
          () => mockDatasource.archiveGroup(any()),
        ).thenThrow(Exception('Archive failed'));

        final result = await repository.archive('grp1');

        expect(result.error, contains('Failed to archive group'));
      });
    });

    group('delete', () {
      test('should delete group successfully', () async {
        when(() => mockDatasource.deleteGroup('grp1')).thenAnswer((_) async {});

        final result = await repository.delete('grp1');

        expect(result.error, isNull);
        verify(() => mockDatasource.deleteGroup('grp1')).called(1);
      });

      test('should return error on delete failure', () async {
        when(
          () => mockDatasource.deleteGroup(any()),
        ).thenThrow(Exception('Delete failed'));

        final result = await repository.delete('grp1');

        expect(result.error, contains('Failed to delete group'));
      });
    });

    group('generateInviteCode', () {
      test('should generate invite code successfully', () async {
        when(
          () => mockDatasource.generateGroupInviteCode('grp1'),
        ).thenAnswer((_) async => 'XYZ789');

        final result = await repository.generateInviteCode('grp1');

        expect(result.data, 'XYZ789');
        expect(result.error, isNull);
      });

      test('should return error on generation failure', () async {
        when(
          () => mockDatasource.generateGroupInviteCode(any()),
        ).thenThrow(Exception('Generation failed'));

        final result = await repository.generateInviteCode('grp1');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to generate invite code'));
      });
    });

    group('watchAll', () {
      test('should stream all groups', () async {
        final entities = [_createGroupEntity()];
        final group = _createGroup();

        when(
          () => mockDatasource.watchAllGroups(),
        ).thenAnswer((_) => Stream.value(entities));
        when(() => mockMapper.toDomain(any())).thenReturn(group);

        final groups = await repository.watchAll().first;

        expect(groups.length, 1);
      });
    });

    group('watchById', () {
      test('should stream group by id', () async {
        final entity = _createGroupEntity();
        final group = _createGroup();

        when(
          () => mockDatasource.watchGroupById('grp1'),
        ).thenAnswer((_) => Stream.value(entity));
        when(() => mockMapper.toDomain(entity)).thenReturn(group);

        final result = await repository.watchById('grp1').first;

        expect(result, isNotNull);
        expect(result!.id, 'grp1');
      });

      test('should return null when group not found', () async {
        when(
          () => mockDatasource.watchGroupById('nonexistent'),
        ).thenAnswer((_) => Stream.value(null));

        final result = await repository.watchById('nonexistent').first;

        expect(result, isNull);
      });
    });

    // ==================== Member Operations ====================
    group('getMembers', () {
      test('should return all members of a group', () async {
        final entities = [_createGroupMemberEntity()];
        final member = _createGroupMember();

        when(
          () => mockDatasource.getGroupMembers('grp1'),
        ).thenAnswer((_) async => entities);
        when(() => mockMapper.memberToDomain(any())).thenReturn(member);

        final result = await repository.getMembers('grp1');

        expect(result.data, isNotNull);
        expect(result.data!.length, 1);
        expect(result.error, isNull);
      });

      test('should return empty list when no members', () async {
        when(
          () => mockDatasource.getGroupMembers('grp1'),
        ).thenAnswer((_) async => []);

        final result = await repository.getMembers('grp1');

        expect(result.data, isNotNull);
        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });

      test('should return error on exception', () async {
        when(
          () => mockDatasource.getGroupMembers(any()),
        ).thenThrow(Exception('Database error'));

        final result = await repository.getMembers('grp1');

        expect(result.data, isNull);
        expect(result.error, contains('Failed to fetch members'));
      });
    });

    group('addMember', () {
      test('should add member successfully', () async {
        final member = _createGroupMember();
        final entity = _createGroupMemberEntity();

        when(() => mockMapper.memberToEntity(member)).thenReturn(entity);
        when(
          () => mockDatasource.insertGroupMember(any()),
        ).thenAnswer((_) async {});

        final result = await repository.addMember(member);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
        verify(() => mockDatasource.insertGroupMember(entity)).called(1);
      });

      test('should return error on add failure', () async {
        final member = _createGroupMember();

        when(
          () => mockMapper.memberToEntity(any()),
        ).thenReturn(_createGroupMemberEntity());
        when(
          () => mockDatasource.insertGroupMember(any()),
        ).thenThrow(Exception('Insert failed'));

        final result = await repository.addMember(member);

        expect(result.data, isNull);
        expect(result.error, contains('Failed to add member'));
      });
    });

    group('updateMember', () {
      test('should update member successfully', () async {
        final member = _createGroupMember();
        final entity = _createGroupMemberEntity();

        when(() => mockMapper.memberToEntity(member)).thenReturn(entity);
        when(
          () => mockDatasource.updateGroupMember(any()),
        ).thenAnswer((_) async {});

        final result = await repository.updateMember(member);

        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });
    });

    group('removeMember', () {
      test('should remove member successfully', () async {
        when(
          () => mockDatasource.removeGroupMember('grp1', 'user1'),
        ).thenAnswer((_) async {});

        final result = await repository.removeMember('grp1', 'user1');

        expect(result.error, isNull);
        verify(
          () => mockDatasource.removeGroupMember('grp1', 'user1'),
        ).called(1);
      });

      test('should return error on remove failure', () async {
        when(
          () => mockDatasource.removeGroupMember(any(), any()),
        ).thenThrow(Exception('Remove failed'));

        final result = await repository.removeMember('grp1', 'user1');

        expect(result.error, contains('Failed to remove member'));
      });
    });

    group('watchMembers', () {
      test('should stream group members', () async {
        final entities = [_createGroupMemberEntity()];
        final member = _createGroupMember();

        when(
          () => mockDatasource.watchGroupMembers('grp1'),
        ).thenAnswer((_) => Stream.value(entities));
        when(() => mockMapper.memberToDomain(any())).thenReturn(member);

        final members = await repository.watchMembers('grp1').first;

        expect(members.length, 1);
      });
    });
  });
}

// Helper functions
GroupEntity _createGroupEntity({
  String id = 'grp1',
  String name = 'Test Group',
  String? inviteCode,
  bool isArchived = false,
}) {
  return GroupEntity(
    id: id,
    name: name,
    description: 'A test group',
    defaultCurrencyCode: 'INR',
    creatorId: 'creator1',
    inviteCode: inviteCode,
    isArchived: isArchived,
    createdAt: DateTime(2024, 1, 1),
  );
}

Group _createGroup({
  String id = 'grp1',
  String name = 'Test Group',
  String? inviteCode,
  bool isArchived = false,
}) {
  return Group(
    id: id,
    name: name,
    description: 'A test group',
    defaultCurrencyCode: 'INR',
    creatorId: 'creator1',
    inviteCode: inviteCode,
    isArchived: isArchived,
    createdAt: DateTime(2024, 1, 1),
  );
}

GroupMemberEntity _createGroupMemberEntity({
  String id = 'member1',
  String groupId = 'grp1',
  String userId = 'user1',
}) {
  return GroupMemberEntity(
    id: id,
    groupId: groupId,
    userId: userId,
    displayName: 'Test User',
    role: 'member',
    currencyCode: 'INR',
    joinedAt: DateTime(2024, 1, 1),
  );
}

GroupMember _createGroupMember({
  String id = 'member1',
  String groupId = 'grp1',
  String userId = 'user1',
}) {
  return GroupMember(
    id: id,
    groupId: groupId,
    userId: userId,
    displayName: 'Test User',
    role: MemberRole.member,
    currencyCode: 'INR',
    joinedAt: DateTime(2024, 1, 1),
  );
}
