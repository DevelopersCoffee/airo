import 'package:equatable/equatable.dart';

/// Represents an Attack-Decay-Sustain-Release (ADSR) envelope for continuous haptic feedback.
class AiroHapticEnvelope extends Equatable {
  /// Constructs an [AiroHapticEnvelope].
  const AiroHapticEnvelope({
    this.attack = const Duration(milliseconds: 30),
    this.decay = const Duration(milliseconds: 80),
    this.sustain = 0.6,
    this.release = const Duration(milliseconds: 150),
  }) : assert(sustain >= 0.0 && sustain <= 1.0, 'Sustain must be between 0.0 and 1.0');

  /// Standard envelope for button press and hold.
  const AiroHapticEnvelope.standard()
      : attack = const Duration(milliseconds: 20),
        decay = const Duration(milliseconds: 50),
        sustain = 0.7,
        release = const Duration(milliseconds: 100);

  /// Smooth gradual envelope for slider drag or scrolling.
  const AiroHapticEnvelope.smooth()
      : attack = const Duration(milliseconds: 50),
        decay = const Duration(milliseconds: 100),
        sustain = 0.5,
        release = const Duration(milliseconds: 200);

  /// Sharp dynamic envelope for explosive or high-energy feedback.
  const AiroHapticEnvelope.sharp()
      : attack = const Duration(milliseconds: 10),
        decay = const Duration(milliseconds: 30),
        sustain = 0.8,
        release = const Duration(milliseconds: 50);

  factory AiroHapticEnvelope.fromJson(Map<String, dynamic> json) {
    return AiroHapticEnvelope(
      attack: Duration(milliseconds: json['attackMs'] as int? ?? 30),
      decay: Duration(milliseconds: json['decayMs'] as int? ?? 80),
      sustain: (json['sustain'] as num? ?? 0.6).toDouble(),
      release: Duration(milliseconds: json['releaseMs'] as int? ?? 150),
    );
  }

  /// Duration for haptic intensity to swell from 0 to peak.
  final Duration attack;

  /// Duration for haptic intensity to decay from peak to sustain level.
  final Duration decay;

  /// Relative sustained intensity level (0.0 to 1.0).
  final double sustain;

  /// Duration for haptic intensity to fade to 0 upon release.
  final Duration release;

  /// Total non-sustained envelope duration (attack + decay).
  Duration get initialDuration => attack + decay;

  Map<String, dynamic> toJson() => {
        'attackMs': attack.inMilliseconds,
        'decayMs': decay.inMilliseconds,
        'sustain': sustain,
        'releaseMs': release.inMilliseconds,
      };

  @override
  List<Object?> get props => [attack, decay, sustain, release];
}
