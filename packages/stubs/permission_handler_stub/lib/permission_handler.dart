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
class Permission {
  final int _value;
  
  const Permission._(this._value);
  
  static const Permission camera = Permission._(0);
  static const Permission contacts = Permission._(1);
  static const Permission location = Permission._(2);
  static const Permission locationAlways = Permission._(3);
  static const Permission locationWhenInUse = Permission._(4);
  static const Permission mediaLibrary = Permission._(5);
  static const Permission microphone = Permission._(6);
  static const Permission phone = Permission._(7);
  static const Permission photos = Permission._(8);
  static const Permission photosAddOnly = Permission._(9);
  static const Permission reminders = Permission._(10);
  static const Permission sensors = Permission._(11);
  static const Permission sms = Permission._(12);
  static const Permission speech = Permission._(13);
  static const Permission storage = Permission._(14);
  static const Permission notification = Permission._(15);
  static const Permission bluetooth = Permission._(16);
  static const Permission manageExternalStorage = Permission._(17);
  static const Permission systemAlertWindow = Permission._(18);
  static const Permission requestInstallPackages = Permission._(19);
  static const Permission appTrackingTransparency = Permission._(20);
  static const Permission criticalAlerts = Permission._(21);
  static const Permission accessNotificationPolicy = Permission._(22);
  static const Permission bluetoothScan = Permission._(23);
  static const Permission bluetoothAdvertise = Permission._(24);
  static const Permission bluetoothConnect = Permission._(25);
  static const Permission nearbyWifiDevices = Permission._(26);
  static const Permission videos = Permission._(27);
  static const Permission audio = Permission._(28);
  static const Permission scheduleExactAlarm = Permission._(29);
  static const Permission sensorsAlways = Permission._(30);
  static const Permission calendarFullAccess = Permission._(31);
  static const Permission calendarWriteOnly = Permission._(32);
  
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

