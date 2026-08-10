import 'package:flutter/foundation.dart';

import 'global_hotkey_port.dart';
import 'hotkey_permission_state.dart';
import 'hotkey_registration_outcome.dart';
import 'hotkey_request.dart';

/// Generic global-hotkey lifecycle: permission gating, register/unregister,
/// and the OS-settings escape hatch, shared by every caller that wants a
/// global hotkey.
///
/// This is the type Quick Capture (#1454, ⌘⇧Space / Win+Shift+Space) and the
/// macOS Everything Browser (#1461, ⌘K) depend on -- neither feature's
/// binding is baked in here; each supplies its own [HotkeyRequest]. What is
/// shared, and what this class exists to own once instead of twice, is: "is
/// this platform even capable of this," "does the OS currently allow it,"
/// and "if not, what does the caller show the user."
///
/// [R05]: this type lives in `feature_mind`, which the web and TV builds
/// never link (see `mind_availability.dart`), so it inherits that exclusion
/// structurally. It additionally treats every non-desktop
/// [TargetPlatform] as [HotkeyPermissionState.unsupported] in its own right,
/// because a phone or tablet build of `feature_mind` -- which does exist,
/// per `module.yaml`'s `supported_devices` -- has no OS concept of a global
/// hotkey to gate.
class GlobalHotkeyRegistrar {
  GlobalHotkeyRegistrar({
    required this.port,
    TargetPlatform Function()? currentPlatform,
  }) : _currentPlatform = currentPlatform ?? (() => defaultTargetPlatform);

  final GlobalHotkeyPort port;
  final TargetPlatform Function() _currentPlatform;
  final Map<String, HotkeyRequest> _registered = {};

  /// Whether the running platform has any concept of a global hotkey at
  /// all. `false` on phone/tablet (Android, iOS) and on web/fuchsia; `true`
  /// on the three desktop OSes #1455 names.
  bool get isSupportedPlatform => switch (_currentPlatform()) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };

  /// The requests currently believed to be live, keyed by
  /// [HotkeyRequest.id]. Reflects this registrar's own bookkeeping, not a
  /// fresh OS query -- an id is added on a successful [register] and
  /// removed by [unregister].
  Map<String, HotkeyRequest> get registered => Map.unmodifiable(_registered);

  /// The OS's current permission answer, short-circuited to
  /// [HotkeyPermissionState.unsupported] without reaching [GlobalHotkeyPort]
  /// when [isSupportedPlatform] is false.
  Future<HotkeyPermissionState> permissionState() async {
    if (!isSupportedPlatform) return HotkeyPermissionState.unsupported;
    return port.permissionState();
  }

  /// Registers [request], gating on [permissionState] first so a caller
  /// never has to duplicate that check. Returns the specific
  /// [HotkeyRegistrationOutcome] -- including [HotkeyRegistrationStatus.conflict]
  /// passed straight through from the OS, which the caller should offer a
  /// rebind for rather than treat as a hard failure.
  Future<HotkeyRegistrationOutcome> register(HotkeyRequest request) async {
    if (request.combination.modifiers.isEmpty) {
      return const HotkeyRegistrationOutcome.failure(
        'A global hotkey needs at least one modifier, otherwise it steals '
        'every unmodified keystroke in the OS.',
      );
    }

    if (!isSupportedPlatform) {
      return const HotkeyRegistrationOutcome.unsupported(
        'This platform has no global hotkey support.',
      );
    }

    final permission = await port.permissionState();
    switch (permission) {
      case HotkeyPermissionState.denied:
        return const HotkeyRegistrationOutcome.permissionDenied(
          'The OS permission for global hotkeys was denied.',
        );
      case HotkeyPermissionState.notDetermined:
        return const HotkeyRegistrationOutcome.permissionNotDetermined(
          'The OS permission for global hotkeys has not been requested yet.',
        );
      case HotkeyPermissionState.unsupported:
        return const HotkeyRegistrationOutcome.unsupported(
          'This platform has no global hotkey support.',
        );
      case HotkeyPermissionState.granted:
        break;
    }

    final outcome = await port.register(request);
    if (outcome.isSuccess) {
      _registered[request.id] = request;
    }
    return outcome;
  }

  /// Releases [id]. A no-op if it was never registered.
  Future<void> unregister(String id) async {
    if (!_registered.containsKey(id)) return;
    await port.unregister(id);
    _registered.remove(id);
  }

  /// Opens the OS's permission settings surface. Only ever call this from
  /// an explicit user action on a denied-state screen -- see
  /// [GlobalHotkeyPort.openOsSettings]'s doc comment. This registrar never
  /// calls it on the caller's behalf.
  Future<void> openOsSettings() => port.openOsSettings();
}
