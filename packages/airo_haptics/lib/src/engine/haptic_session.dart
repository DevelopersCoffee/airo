import 'dart:async';
import '../models/haptic_envelope.dart';
import '../models/haptic_event.dart';
import '../models/haptic_options.dart';
import '../models/haptic_pattern.dart';
import 'haptic_player.dart';

/// Manages an isolated haptic execution session owning engine lifecycle, queueing, and cancellation.
class AiroHapticSession {
  /// Constructs an [AiroHapticSession].
  AiroHapticSession({
    required this.id,
    required Future<AiroHapticPlayer> Function(AiroHapticPattern pattern, AiroHapticOptions? options) onPlayPattern,
    required Future<void> Function(String patternId) onStopPattern,
    Future<void> Function(String patternId, double intensity, double sharpness)? onUpdatePattern,
  })  : _onPlayPattern = onPlayPattern,
        _onStopPattern = onStopPattern,
        _onUpdatePattern = onUpdatePattern;

  final String id;
  final Future<AiroHapticPlayer> Function(AiroHapticPattern pattern, AiroHapticOptions? options) _onPlayPattern;
  final Future<void> Function(String patternId) _onStopPattern;
  final Future<void> Function(String patternId, double intensity, double sharpness)? _onUpdatePattern;

  bool _isActive = true;
  AiroHapticPlayer? _activePlayer;

  bool get isActive => _isActive;
  AiroHapticPlayer? get activePlayer => _activePlayer;

  /// Plays a pattern scoped to this session.
  Future<AiroHapticPlayer?> play(
    AiroHapticPattern pattern, {
    AiroHapticOptions? options,
  }) async {
    if (!_isActive) return null;
    await stop();

    final player = await _onPlayPattern(
      pattern,
      options ?? AiroHapticOptions(tag: 'session_$id'),
    );

    _activePlayer = player;
    return player;
  }

  /// Plays continuous haptic vibration shaped by an ADSR envelope.
  Future<AiroHapticPlayer?> playContinuous({
    double intensity = 0.5,
    double sharpness = 0.5,
    AiroHapticEnvelope envelope = const AiroHapticEnvelope(),
    AiroHapticOptions? options,
  }) async {
    if (!_isActive) return null;

    final events = <AiroHapticEvent>[
      AiroHapticEvent.continuous(
        duration: envelope.initialDuration,
        intensity: intensity,
        sharpness: sharpness,
      ),
    ];

    final pattern = AiroHapticPattern(
      id: 'session_${id}_envelope_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Continuous Envelope Pattern',
      events: events,
    );

    return play(pattern, options: options);
  }

  /// Updates active haptic parameters in real time.
  Future<void> update({
    double? intensity,
    double? sharpness,
  }) async {
    if (!_isActive || _activePlayer == null) return;
    await _activePlayer!.update(intensity: intensity, sharpness: sharpness);
  }

  /// Stops all active haptic playback for this session.
  Future<void> stop() async {
    if (_activePlayer != null) {
      _activePlayer!.stop();
      await _onStopPattern(_activePlayer!.pattern.id);
      _activePlayer = null;
    }
  }

  /// Ends and disposes the session.
  void dispose() {
    _isActive = false;
    stop();
  }
}
