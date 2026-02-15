import '../../domain/entities/account.dart';
import '../datasources/coins_local_datasource.dart';

/// Mapper for Account entity <-> AccountEntity conversion
///
/// Phase: 1 (Foundation)
class AccountMapper {
  /// Convert database entity to domain entity
  Account toDomain(AccountEntity entity) {
    return Account(
      id: entity.id,
      name: entity.name,
      type: _parseAccountType(entity.type),
      balanceCents: entity.balanceCents,
      currencyCode: entity.currencyCode,
      iconName: entity.iconName,
      color: entity.color,
      isDefault: entity.isDefault,
      isArchived: entity.isArchived,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert domain entity to database entity
  AccountEntity toEntity(Account account) {
    return AccountEntity(
      id: account.id,
      name: account.name,
      type: account.type.name,
      balanceCents: account.balanceCents,
      currencyCode: account.currencyCode,
      iconName: account.iconName,
      color: account.color,
      isDefault: account.isDefault,
      isArchived: account.isArchived,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }

  AccountType _parseAccountType(String type) {
    return AccountType.values.firstWhere(
      (t) => t.name == type,
      orElse: () => AccountType.cash,
    );
  }
}

