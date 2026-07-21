import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vault_config.dart';
import 'vault_providers.dart';

/// Lifecycle state of the vault session.
sealed class VaultSessionState {
  const VaultSessionState();
}

final class VaultLocked extends VaultSessionState {
  const VaultLocked();
}

final class VaultUnlocking extends VaultSessionState {
  const VaultUnlocking();
}

final class VaultUnlocked extends VaultSessionState {
  const VaultUnlocked();
}

/// Device cannot do biometric/device-credential auth, so vault creation must
/// not be offered under the ADR 0009 fail-closed contract.
final class VaultUnavailable extends VaultSessionState {
  const VaultUnavailable();
}

final class VaultAuthError extends VaultSessionState {
  const VaultAuthError(this.failure);

  final BaseFailure failure;
}

/// Owns the vault DEK for the duration of an unlocked session.
///
/// The DEK is held privately and never exposed through state. Consumers run
/// sensitive operations through [withKey]. The DEK is zeroed in place on lock,
/// idle timeout, app background, and disposal. Key rotation is deliberately
/// not exposed here because `VaultKeyManager.rotateKey` is destructive until a
/// re-encryption migration exists.
class VaultSessionNotifier extends Notifier<VaultSessionState> {
  Timer? _idleTimer;
  List<int>? _dek;
  final Set<List<int>> _activeOperationKeys = {};
  var _disposed = false;
  var _unlockGeneration = 0;

  @override
  VaultSessionState build() {
    ref.onDispose(() {
      _disposed = true;
      _invalidateUnlock();
      _idleTimer?.cancel();
      _revokeOperationKeys();
      _zeroDek();
    });
    return const VaultLocked();
  }

  /// Prompts for biometrics and, on success, caches the DEK.
  ///
  /// Fail-closed: unavailable devices get [VaultUnavailable] without an auth
  /// prompt; authentication failures get [VaultAuthError].
  Future<void> unlock() async {
    if (_disposed) return;
    if (state is VaultUnlocking || state is VaultUnlocked) return;

    final unlockGeneration = ++_unlockGeneration;
    state = const VaultUnlocking();
    final keyManager = ref.read(vaultKeyManagerProvider);

    final bool isAvailable;
    try {
      isAvailable = await keyManager.isEncryptionAvailable();
    } catch (_) {
      if (_isCurrentUnlock(unlockGeneration)) {
        state = const VaultUnavailable();
      }
      return;
    }
    if (!_isCurrentUnlock(unlockGeneration)) return;

    if (!isAvailable) {
      state = const VaultUnavailable();
      return;
    }

    final result = await keyManager.getDatabaseKey();
    if (!_isCurrentUnlock(unlockGeneration)) {
      switch (result) {
        case Success<List<int>>(:final value):
          _zeroBytes(value);
        case Err<List<int>>():
          break;
      }
      return;
    }

    switch (result) {
      case Success<List<int>>(:final value):
        _dek = value;
        state = const VaultUnlocked();
        _resetIdleTimer();
      case Err<List<int>>():
        state = VaultAuthError(result.failure);
    }
  }

  /// Runs [operation] with the DEK if unlocked; returns null otherwise.
  ///
  /// A successful [withKey] call counts as user activity and resets the idle
  /// timer.
  Future<T?> withKey<T>(
    Future<T> Function(List<int> keyBytes) operation,
  ) async {
    final dek = _dek;
    if (dek == null || state is! VaultUnlocked) return null;
    final generation = _unlockGeneration;
    final operationKey = List<int>.of(dek);
    _activeOperationKeys.add(operationKey);
    _resetIdleTimer();
    try {
      final result = await operation(operationKey);
      if (!_isCurrentUnlock(generation) || state is! VaultUnlocked) {
        return null;
      }
      return result;
    } finally {
      _activeOperationKeys.remove(operationKey);
      _revokeKey(operationKey);
    }
  }

  /// Immediately locks the vault and zeroes the DEK.
  void lock() {
    _invalidateUnlock();
    _idleTimer?.cancel();
    _revokeOperationKeys();
    _zeroDek();
    if (!_disposed) {
      state = const VaultLocked();
    }
  }

  /// Called by the lifecycle observer when the app goes to background.
  void onAppBackground() {
    if (_disposed) return;
    if (state is VaultUnlocking || state is VaultUnlocked) lock();
  }

  void _resetIdleTimer() {
    if (_disposed) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(VaultConfig.autoLockDuration, lock);
  }

  bool _isCurrentUnlock(int unlockGeneration) =>
      !_disposed && _unlockGeneration == unlockGeneration;

  void _invalidateUnlock() {
    _unlockGeneration++;
  }

  void _zeroDek() {
    final dek = _dek;
    if (dek != null) {
      _zeroBytes(dek);
    }
    _dek = null;
  }

  void _zeroBytes(List<int> bytes) {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  }

  void _revokeOperationKeys() {
    for (final key in _activeOperationKeys.toList(growable: false)) {
      _revokeKey(key);
    }
    _activeOperationKeys.clear();
  }

  void _revokeKey(List<int> bytes) {
    _zeroBytes(bytes);
    bytes.clear();
  }
}

final vaultSessionProvider =
    NotifierProvider<VaultSessionNotifier, VaultSessionState>(
      VaultSessionNotifier.new,
    );
