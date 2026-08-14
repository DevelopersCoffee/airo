/// Explicit consent for off-device (cloud) processing of a Mind request.
///
/// #1631's AC is specific: below-threshold devices skip local LLM entirely
/// and fall back to cloud "with explicit user consent for any off-device
/// processing." This gate is that consent, decoupled from any particular
/// storage mechanism -- the app shell wires a persisted implementation
/// (settings, secure storage, whatever pattern `ModelPreloadPreferences`
/// already established); tests and the default seam use
/// [InMemoryLlmCloudConsentGate].
abstract interface class LlmCloudConsentGate {
  Future<bool> hasConsented();
}

/// Default, non-persisted consent gate. Starts unconsented -- cloud fallback
/// is opt-in, never assumed.
class InMemoryLlmCloudConsentGate implements LlmCloudConsentGate {
  InMemoryLlmCloudConsentGate({bool granted = false}) : _granted = granted;

  bool _granted;

  @override
  Future<bool> hasConsented() async => _granted;

  Future<void> grant() async {
    _granted = true;
  }

  Future<void> revoke() async {
    _granted = false;
  }
}
