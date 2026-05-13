import 'dart:convert';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../domain/entities/shared_expense.dart';
import '../../domain/entities/split_entry.dart';
import '../datasources/coins_local_datasource.dart';

/// Mapper for Group entity <-> GroupEntity conversion
///
/// Phase: 2 (Split Engine)
class GroupMapper {
  /// Convert database entity to domain entity
  Group toDomain(GroupEntity entity) {
    return Group(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      iconUrl: entity.iconUrl,
      defaultCurrencyCode: entity.defaultCurrencyCode,
      members: [], // Members loaded separately
      settings: _parseSettings(entity.settings),
      creatorId: entity.creatorId,
      inviteCode: entity.inviteCode,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isArchived: entity.isArchived,
    );
  }

  /// Convert domain entity to database entity
  GroupEntity toEntity(Group group) {
    return GroupEntity(
      id: group.id,
      name: group.name,
      description: group.description,
      iconUrl: group.iconUrl,
      defaultCurrencyCode: group.defaultCurrencyCode,
      settings: jsonEncode({
        'simplifyDebts': group.settings.simplifyDebts,
        'defaultEqualSplit': group.settings.defaultEqualSplit,
        'allowMultiCurrency': group.settings.allowMultiCurrency,
        'defaultCurrencyCode': group.settings.defaultCurrencyCode,
      }),
      creatorId: group.creatorId,
      inviteCode: group.inviteCode,
      isArchived: group.isArchived,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    );
  }

  /// Convert member database entity to domain entity
  GroupMember memberToDomain(GroupMemberEntity entity) {
    return GroupMember(
      id: entity.id,
      groupId: entity.groupId,
      userId: entity.userId,
      displayName: entity.displayName,
      avatarUrl: entity.avatarUrl,
      role: _parseMemberRole(entity.role),
      currencyCode: entity.currencyCode,
      joinedAt: entity.joinedAt,
    );
  }

  /// Convert member domain entity to database entity
  GroupMemberEntity memberToEntity(GroupMember member) {
    return GroupMemberEntity(
      id: member.id,
      groupId: member.groupId,
      userId: member.userId,
      displayName: member.displayName,
      avatarUrl: member.avatarUrl,
      role: member.role.name,
      currencyCode: member.currencyCode,
      joinedAt: member.joinedAt,
    );
  }

  SharedExpense expenseToDomain(SharedExpenseEntity entity) {
    final splitType = _parseSplitType(entity.splitType);
    return SharedExpense(
      id: entity.id,
      groupId: entity.groupId,
      description: entity.description,
      totalAmountCents: entity.totalAmountCents,
      currencyCode: entity.currencyCode,
      categoryId: entity.categoryId ?? 'general',
      paidByUserId: entity.paidByUserId,
      splitType: splitType,
      splits: entity.splits
          .map((split) => splitToDomain(split, splitType))
          .toList(),
      notes: entity.notes,
      receiptId: entity.receiptId,
      expenseDate: entity.expenseDate,
      isDeleted: entity.isDeleted,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  SharedExpenseEntity expenseToEntity(SharedExpense expense) {
    return SharedExpenseEntity(
      id: expense.id,
      groupId: expense.groupId,
      description: expense.description,
      totalAmountCents: expense.totalAmountCents,
      currencyCode: expense.currencyCode,
      paidByUserId: expense.paidByUserId,
      splitType: expense.splitType.name,
      splits: expense.splits.map(splitToEntity).toList(),
      categoryId: expense.categoryId,
      notes: expense.notes,
      receiptId: expense.receiptId,
      expenseDate: expense.expenseDate,
      isDeleted: expense.isDeleted,
      createdAt: expense.createdAt,
      updatedAt: expense.updatedAt,
    );
  }

  SplitEntry splitToDomain(SplitEntryEntity entity, SplitType splitType) {
    return SplitEntry(
      id: entity.id,
      sharedExpenseId: entity.sharedExpenseId,
      userId: entity.userId,
      amountCents: entity.amountCents,
      percentage: splitType == SplitType.percentage
          ? entity.shareValue.toDouble()
          : null,
      shares: splitType == SplitType.shares ? entity.shareValue : null,
      isPaid: entity.isSettled,
      createdAt: entity.createdAt,
    );
  }

  SplitEntryEntity splitToEntity(SplitEntry split) {
    return SplitEntryEntity(
      id: split.id,
      sharedExpenseId: split.sharedExpenseId,
      userId: split.userId,
      amountCents: split.amountCents,
      shareValue: split.shares ?? (split.percentage?.round() ?? 100),
      isSettled: split.isPaid,
      createdAt: split.createdAt,
    );
  }

  GroupSettings _parseSettings(String? settingsJson) {
    if (settingsJson == null || settingsJson.isEmpty) {
      return const GroupSettings();
    }
    try {
      final decoded = jsonDecode(settingsJson) as Map<String, dynamic>;
      return GroupSettings(
        simplifyDebts: decoded['simplifyDebts'] as bool? ?? true,
        defaultEqualSplit: decoded['defaultEqualSplit'] as bool? ?? true,
        allowMultiCurrency: decoded['allowMultiCurrency'] as bool? ?? false,
        defaultCurrencyCode: decoded['defaultCurrencyCode'] as String? ?? 'INR',
      );
    } catch (_) {
      return const GroupSettings();
    }
  }

  MemberRole _parseMemberRole(String role) {
    return MemberRole.values.firstWhere(
      (r) => r.name == role,
      orElse: () => MemberRole.member,
    );
  }

  SplitType _parseSplitType(String type) {
    return SplitType.values.firstWhere(
      (t) => t.name == type,
      orElse: () => SplitType.equal,
    );
  }
}
