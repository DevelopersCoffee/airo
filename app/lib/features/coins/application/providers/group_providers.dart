import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/locale_settings.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/repositories/group_repository.dart';
import '../use_cases/add_group_member_use_case.dart';
import '../use_cases/create_group_use_case.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../data/mappers/group_mapper.dart';
import 'expense_providers.dart';

/// Group repository provider
///
/// Uses local datasource for offline-first storage.
/// On web, throws UnimplementedError (no SQLite support).
///
/// Phase: 2 (Split Engine)
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  if (kIsWeb) {
    throw UnimplementedError('Coins feature not supported on web (no SQLite)');
  }
  final datasource = ref.watch(coinsLocalDatasourceProvider);
  return GroupRepositoryImpl(datasource, GroupMapper());
});

/// Watch all groups
final allGroupsProvider = StreamProvider<List<Group>>((ref) {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.watchAll();
});

/// Watch active (non-archived) groups
final activeGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final repo = ref.watch(groupRepositoryProvider);
  final result = await repo.findActive();
  return result.data ?? [];
});

/// Watch a specific group by ID
final groupByIdProvider = StreamProvider.family<Group?, String>((ref, id) {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.watchById(id);
});

/// Watch group members
final groupMembersProvider = StreamProvider.family<List<GroupMember>, String>((
  ref,
  groupId,
) {
  final repo = ref.watch(groupRepositoryProvider);
  return repo.watchMembers(groupId);
});

/// Watch group expenses
final groupExpensesProvider =
    StreamProvider.family<List<SharedExpense>, String>((ref, groupId) {
      final repo = ref.watch(groupRepositoryProvider);
      return repo.watchExpenses(groupId);
    });

/// Currently selected group (for navigation state)
final selectedGroupIdProvider = StateProvider<String?>((ref) => null);

/// Selected group details
final selectedGroupProvider = Provider<AsyncValue<Group?>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider);
  if (groupId == null) return const AsyncValue.data(null);
  return ref.watch(groupByIdProvider(groupId));
});

final createGroupUseCaseProvider = Provider<CreateGroupUseCase>((ref) {
  return CreateGroupUseCase(ref.watch(groupRepositoryProvider));
});

final addGroupMemberUseCaseProvider = Provider<AddGroupMemberUseCase>((ref) {
  return AddGroupMemberUseCase(ref.watch(groupRepositoryProvider));
});

/// Create group state notifier
final createGroupProvider =
    StateNotifierProvider.autoDispose<CreateGroupNotifier, AsyncValue<Group?>>(
      (ref) => CreateGroupNotifier(ref),
    );

class CreateGroupNotifier extends StateNotifier<AsyncValue<Group?>> {
  final Ref _ref;

  CreateGroupNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> createGroup(Group group) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupRepositoryProvider);
      final result = await repo.create(group);
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
      } else {
        state = AsyncValue.data(result.data);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createGroupFromInput({
    required String name,
    String? description,
    required String creatorId,
    String creatorDisplayName = 'You',
  }) async {
    state = const AsyncValue.loading();
    try {
      final useCase = _ref.read(createGroupUseCaseProvider);
      final currencyCode = _ref.read(currencyFormatterProvider).currency.code;
      final result = await useCase.execute(
        CreateGroupParams(
          name: name,
          description: description,
          creatorId: creatorId,
          creatorDisplayName: creatorDisplayName,
          defaultCurrencyCode: currencyCode,
        ),
      );
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
      } else {
        state = AsyncValue.data(result.data);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateGroup(Group group) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupRepositoryProvider);
      final result = await repo.update(group);
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
      } else {
        state = AsyncValue.data(result.data);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Add member state notifier
final addMemberProvider =
    StateNotifierProvider.autoDispose<AddMemberNotifier, AsyncValue<void>>(
      (ref) => AddMemberNotifier(ref),
    );

class AddMemberNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AddMemberNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addMember(GroupMember member) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupRepositoryProvider);
      await repo.addMember(member);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMemberFromInput({
    required String groupId,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final useCase = _ref.read(addGroupMemberUseCaseProvider);
      final currencyCode = _ref.read(currencyFormatterProvider).currency.code;
      final result = await useCase.execute(
        AddGroupMemberParams(
          groupId: groupId,
          displayName: displayName,
          currencyCode: currencyCode,
        ),
      );
      if (result.error != null) {
        state = AsyncValue.error(result.error!, StackTrace.current);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeMember(String groupId, String userId) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupRepositoryProvider);
      await repo.removeMember(groupId, userId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
