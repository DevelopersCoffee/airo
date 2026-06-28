/// Stub implementation of permission_handler for TV builds
library;

/// Permission status
enum PermissionStatus {
  denied,
  granted,
  restricted,
  limited,
  permanentlyDenied,
  provisional,
}

/// Extension on PermissionStatus
extension PermissionStatusExtension on PermissionStatus {
  bool get isGranted => this == PermissionStatus.granted;
  bool get isDenied => this == PermissionStatus.denied;
  bool get isPermanentlyDenied => this == PermissionStatus.permanentlyDenied;
  bool get isRestricted => this == PermissionStatus.restricted;
  bool get isLimited => this == PermissionStatus.limited;
}

/// Permission class
enum Permission {
  camera._(0),
  contacts._(1),
  location._(2),
  locationAlways._(3),
  locationWhenInUse._(4),
  mediaLibrary._(5),
  microphone._(6),
  phone._(7),
  photos._(8),
  photosAddOnly._(9),
  reminders._(10),
  sensors._(11),
  sms._(12),
  speech._(13),
  storage._(14),
  notification._(15),
  bluetooth._(16),
  manageExternalStorage._(17),
  systemAlertWindow._(18),
  requestInstallPackages._(19),
  appTrackingTransparency._(20),
  criticalAlerts._(21),
  accessNotificationPolicy._(22),
  bluetoothScan._(23),
  bluetoothAdvertise._(24),
  bluetoothConnect._(25),
  nearbyWifiDevices._(26),
  videos._(27),
  audio._(28),
  scheduleExactAlarm._(29),
  sensorsAlways._(30),
  calendarFullAccess._(31),
  calendarWriteOnly._(32);

  const Permission._(this._value);
  final int _value;

  /// Check if granted - returns denied on TV
  Future<bool> get isGranted async => false;

  /// Check if denied - returns true on TV
  Future<bool> get isDenied async => true;

  /// Request permission - returns denied on TV
  Future<PermissionStatus> request() async => PermissionStatus.denied;

  /// Get status - returns denied on TV
  Future<PermissionStatus> get status async => PermissionStatus.denied;
}

/// Open app settings
Future<bool> openAppSettings() async => false;
