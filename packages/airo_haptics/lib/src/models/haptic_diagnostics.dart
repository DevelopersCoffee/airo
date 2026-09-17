import 'package:equatable/equatable.dart';

/// Diagnostics snapshot of the haptic engine runtime state.
class AiroHapticDiagnostics extends Equatable {
  const AiroHapticDiagnostics({
    required this.totalTriggers,
    required this.playedCount,
    required this.droppedCount,
    required this.activeBackend,
    this.lastTriggeredType,
    this.lastTriggerTimestamp,
  });

  const AiroHapticDiagnostics.empty({
    this.activeBackend = 'none',
  })  : totalTriggers = 0,
        playedCount = 0,
        droppedCount = 0,
        lastTriggeredType = null,
        lastTriggerTimestamp = null;

  factory AiroHapticDiagnostics.fromJson(Map<String, dynamic> json) {
    return AiroHapticDiagnostics(
      totalTriggers: json['totalTriggers'] as int? ?? 0,
      playedCount: json['playedCount'] as int? ?? 0,
      droppedCount: json['droppedCount'] as int? ?? 0,
      activeBackend: json['activeBackend'] as String? ?? 'unknown',
      lastTriggeredType: json['lastTriggeredType'] as String?,
      lastTriggerTimestamp: json['lastTriggerTimestamp'] != null
          ? DateTime.parse(json['lastTriggerTimestamp'] as String)
          : null,
    );
  }

  final int totalTriggers;
  final int playedCount;
  final int droppedCount;
  final String activeBackend;
  final String? lastTriggeredType;
  final DateTime? lastTriggerTimestamp;

  Map<String, dynamic> toJson() => {
        'totalTriggers': totalTriggers,
        'playedCount': playedCount,
        'droppedCount': droppedCount,
        'activeBackend': activeBackend,
        'lastTriggeredType': lastTriggeredType,
        'lastTriggerTimestamp': lastTriggerTimestamp?.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        totalTriggers,
        playedCount,
        droppedCount,
        activeBackend,
        lastTriggeredType,
        lastTriggerTimestamp,
      ];
}
