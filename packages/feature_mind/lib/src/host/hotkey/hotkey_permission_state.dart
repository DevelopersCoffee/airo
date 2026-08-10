/// Where a desktop OS stands on letting Airo Mind register a global hotkey.
///
/// Four states, not two, because "no" is not one thing: a user who has never
/// been asked (`notDetermined`) needs a different prompt than one who
/// declined (`denied`), and an OS that has no such permission concept at all
/// (`unsupported` -- phone/tablet builds, or a Linux desktop environment with
/// no portal for this) must not be shown either.
///
/// This is deliberately OS-agnostic. macOS backs it with Accessibility or
/// Input Monitoring authorisation, Windows has no such prompt (its failure
/// mode is a hotkey conflict, modelled separately by
/// `HotkeyRegistrationOutcome`, not by this enum), and Linux depends on the
/// desktop environment / portal in use. `GlobalHotkeyPort` implementations
/// translate their platform's own answer into one of these four values so
/// callers -- Quick Capture (#1454) and the macOS Everything Browser (#1461)
/// alike -- read one shape regardless of OS.
enum HotkeyPermissionState {
  /// The OS has authorised global hotkey registration; [register] may be
  /// called.
  granted,

  /// The user was asked and said no. The only recovery path is the OS's own
  /// settings surface -- see `GlobalHotkeyPort.openOsSettings`, which must
  /// only run from an explicit button tap, never automatically.
  denied,

  /// The OS has not yet been asked. Distinct from [denied] because the UI
  /// copy differs: "this needs a permission" versus "you said no, here's how
  /// to undo that."
  notDetermined,

  /// This platform has no global-hotkey permission model to satisfy, or
  /// hotkeys are not available on it at all (a phone/tablet build, or a
  /// Linux desktop environment without a hotkey portal). The surface must
  /// degrade -- e.g. tray-only -- rather than show a permission prompt that
  /// can never be satisfied.
  unsupported,
}
