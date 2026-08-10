import 'hotkey_permission_state.dart';
import 'hotkey_registration_outcome.dart';
import 'hotkey_request.dart';

/// The per-OS half of global hotkey support: everything that actually talks
/// to macOS, Windows, or Linux.
///
/// `GlobalHotkeyRegistrar` owns the generic lifecycle (register, unregister,
/// permission gating) and is the type Quick Capture (#1454) and the
/// Everything Browser palette (#1461) depend on; this interface is the seam
/// a concrete per-OS backend implements underneath it. No implementation
/// ships in this change -- see [UnsupportedGlobalHotkeyPort]'s doc comment
/// for why -- so every method here is exercised in tests only through fakes.
abstract class GlobalHotkeyPort {
  /// The OS's current answer for this app, translated to
  /// [HotkeyPermissionState]. Must not have side effects -- callers may poll
  /// this, e.g. after the user returns from the OS settings screen.
  Future<HotkeyPermissionState> permissionState();

  /// Attempts to bind [request.combination] to [request.id]. Must not be
  /// called while [permissionState] would answer anything other than
  /// [HotkeyPermissionState.granted] -- `GlobalHotkeyRegistrar` enforces
  /// that gate before reaching this method, so an implementation may assume
  /// permission is already granted.
  Future<HotkeyRegistrationOutcome> register(HotkeyRequest request);

  /// Releases a previously registered id. A no-op if [id] was never
  /// registered or was already released.
  Future<void> unregister(String id);

  /// Opens whatever OS surface lets the user grant this permission --
  /// System Settings' Privacy pane on macOS, the equivalent on Linux, a
  /// no-op on Windows (which has no such prompt).
  ///
  /// Callers must only invoke this from an explicit user action (a button
  /// tap on a denied-state screen). Nothing in this package calls it
  /// automatically -- an app that opens OS settings on the user's behalf
  /// without being asked is the exact failure mode #1455 rules out.
  Future<void> openOsSettings();
}

/// The [GlobalHotkeyPort] used until a real per-OS backend is wired in.
///
/// This change lands the generic API -- permission-state model, lifecycle,
/// conflict/rebind and unsupported-OS handling -- that both Quick Capture
/// and the Everything Browser palette build against. Wiring an actual
/// backend (macOS Accessibility/Input Monitoring via platform channels,
/// Windows `RegisterHotKey`, a Linux portal) is native-code work that needs
/// on-device verification per platform and is tracked separately (#1592).
/// Until that lands, every request answers [HotkeyPermissionState.unsupported]
/// so a caller never sees a false [HotkeyPermissionState.granted] and skips
/// straight to the tray-only degradation path the issue calls for on Linux.
class UnsupportedGlobalHotkeyPort implements GlobalHotkeyPort {
  const UnsupportedGlobalHotkeyPort();

  static const _reason =
      'Global hotkeys are not wired up on this build yet.';

  @override
  Future<HotkeyPermissionState> permissionState() async =>
      HotkeyPermissionState.unsupported;

  @override
  Future<HotkeyRegistrationOutcome> register(HotkeyRequest request) async =>
      const HotkeyRegistrationOutcome.unsupported(_reason);

  @override
  Future<void> unregister(String id) async {}

  @override
  Future<void> openOsSettings() async {}
}
