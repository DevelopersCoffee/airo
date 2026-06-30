import 'package:platform_identity/platform_identity.dart';

enum PermissionLevel {
  denied,
  restricted,
  allowed,
}

abstract class SecurityPolicy {
  String get name;
  bool evaluate(PlatformIdentifier subject, PlatformIdentifier resource);
}

class Permission {
  const Permission(this.name, this.level);
  final String name;
  final PermissionLevel level;
}

abstract class SecurityManager {
  Future<bool> requestPermission(PlatformIdentifier subject, Permission permission);
  bool hasPermission(PlatformIdentifier subject, String permissionName);
  
  Future<String> getSecret(String key);
  Future<void> storeSecret(String key, String value);
  
  String encrypt(String plainText);
  String decrypt(String cipherText);
  
  bool verifySignature(String payload, String signature, String publicKey);
}
