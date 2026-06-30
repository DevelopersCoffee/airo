
abstract class NativeBridge {
  Future<void> initialize();
  Future<void> shutdown();
}

abstract class RustBridge implements NativeBridge {}
abstract class CBridge implements NativeBridge {}
abstract class SwiftBridge implements NativeBridge {}
