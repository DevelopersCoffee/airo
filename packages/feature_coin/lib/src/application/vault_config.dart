/// Timing and storage constants for the Airo Coin vault. Centralized so a
/// future settings screen can make them configurable without hunting
/// through the session/clipboard code.
abstract final class VaultConfig {
  /// Idle time after which the vault auto-locks and the DEK is zeroed.
  static const autoLockDuration = Duration(seconds: 60);

  /// Delay before a copied value is auto-cleared from the clipboard.
  static const clipboardClearDuration = Duration(seconds: 30);

  /// sqflite file name inside the app documents directory.
  static const databaseFileName = 'airo_coin_vault.db';
}
