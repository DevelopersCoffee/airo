import 'package:flutter/foundation.dart';

/// Platform capability descriptor for transfer engine features.
@immutable
class AiroPlatformCapabilities {
  const AiroPlatformCapabilities({
    required this.backgroundDownloads,
    required this.pauseResume,
    required this.networkConstraints,
    required this.chargingConstraints,
    required this.checksumVerification,
    required this.backgroundProcessing,
    required this.notifications,
  });

  final bool backgroundDownloads;
  final bool pauseResume;
  final bool networkConstraints;
  final bool chargingConstraints;
  final bool checksumVerification;
  final bool backgroundProcessing;
  final bool notifications;

  Map<String, Object> toMap() => {
    'backgroundDownloads': backgroundDownloads,
    'pauseResume': pauseResume,
    'networkConstraints': networkConstraints,
    'chargingConstraints': chargingConstraints,
    'checksumVerification': checksumVerification,
    'backgroundProcessing': backgroundProcessing,
    'notifications': notifications,
  };

  factory AiroPlatformCapabilities.fromMap(Map<Object?, Object?> map) {
    return AiroPlatformCapabilities(
      backgroundDownloads: map['backgroundDownloads'] as bool? ?? true,
      pauseResume: map['pauseResume'] as bool? ?? true,
      networkConstraints: map['networkConstraints'] as bool? ?? true,
      chargingConstraints: map['chargingConstraints'] as bool? ?? true,
      checksumVerification: map['checksumVerification'] as bool? ?? true,
      backgroundProcessing: map['backgroundProcessing'] as bool? ?? true,
      notifications: map['notifications'] as bool? ?? true,
    );
  }
}
