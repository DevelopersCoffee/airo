import 'package:flutter/foundation.dart';

/// How a [HotkeyRequest] was resolved.
///
/// Six shapes, not a bool, because "it didn't register" is not one failure:
/// a Windows chord held by another process ([conflict]) needs a rebind
/// affordance, a denied macOS permission ([permissionDenied]) needs a
/// settings button, and an unsupported Linux desktop ([unsupported]) needs
/// neither -- it needs the surface to say so and degrade to tray-only. Only
/// [failure] is the generic bucket, reserved for OS errors none of the named
/// states cover.
enum HotkeyRegistrationStatus {
  success,
  permissionDenied,
  permissionNotDetermined,

  /// The chord is already held by another process (Windows's
  /// `RegisterHotKey` failure mode). Recoverable: the caller should offer a
  /// rebind, not an error toast.
  conflict,
  unsupported,
  failure,
}

/// Result of [GlobalHotkeyPort.register] / [GlobalHotkeyRegistrar.register],
/// pairing the outcome with a human-readable reason so the caller can show
/// it verbatim without re-deriving copy from the enum value.
@immutable
class HotkeyRegistrationOutcome {
  const HotkeyRegistrationOutcome.success()
    : status = HotkeyRegistrationStatus.success,
      detail = '';

  const HotkeyRegistrationOutcome.permissionDenied(this.detail)
    : status = HotkeyRegistrationStatus.permissionDenied;

  const HotkeyRegistrationOutcome.permissionNotDetermined(this.detail)
    : status = HotkeyRegistrationStatus.permissionNotDetermined;

  const HotkeyRegistrationOutcome.conflict(this.detail)
    : status = HotkeyRegistrationStatus.conflict;

  const HotkeyRegistrationOutcome.unsupported(this.detail)
    : status = HotkeyRegistrationStatus.unsupported;

  const HotkeyRegistrationOutcome.failure(this.detail)
    : status = HotkeyRegistrationStatus.failure;

  final HotkeyRegistrationStatus status;
  final String detail;

  bool get isSuccess => status == HotkeyRegistrationStatus.success;

  /// Whether the caller should offer a rebind affordance rather than an
  /// error toast (the Windows-conflict case from #1455's "Done when").
  bool get isRecoverableByRebind => status == HotkeyRegistrationStatus.conflict;
}
