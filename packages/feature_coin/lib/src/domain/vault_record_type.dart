/// The four vault record kinds, in add-picker order. Enum names are used as
/// route path parameters (`/money/vault/add/<name>`), so do not rename values
/// without migrating routes.
enum VaultRecordType { bankAccount, panCard, creditCard, secureDocument }
