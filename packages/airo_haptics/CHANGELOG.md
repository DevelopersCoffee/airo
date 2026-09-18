## 1.1.0

- Added dynamic live parameter tuning via `player.update(intensity: ..., sharpness: ...)` and `AiroHaptics.createPlayer()`.
- Added first-class `AiroHapticSession` for session lifecycle, queueing, and cancellation.
- Added Attack-Decay-Sustain-Release (`AiroHapticEnvelope`) continuous envelope player (`AiroHaptics.playContinuous()`).
- Added Apple AHAP design format parser (`AiroHapticPattern.fromAhap()`).
- Added `AiroHapticProfile` tuning profiles (`default`, `minimal`, `gaming`, `accessibility`, `tv`, `media`, `assistant`).
- Added testing assertion matchers (`expectHapticPlayed`, `expectNoHapticPlayed`, `expectHapticPatternPlayed`).
- Upgraded interactive Haptic Lab in `example/` with ADSR envelope sliders, AHAP sample player, and profile switcher.

## 1.0.0

- Initial release of `airo_haptics` cross-platform Flutter haptics engine.
- Semantic feedback (20 standard feedback types).
- Physical impact shortcuts (light, medium, heavy, soft, rigid) & variable sharpness.
- Custom pattern engine & preset waves (`doubleClick`, `successWave`, `errorAlert`, `heartbeat`, `rampUp`).
- Capability detection (`AiroHapticCapabilities`).
- Throttling, coalescing, themes, diagnostics, and testing fakes.
