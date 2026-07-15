import 'dart:io';

/// Device class categories used to select appropriate memory budgets.
///
/// Each class represents a hardware tier with different memory constraints.
/// Use [DeviceClass.detect] to determine the class at runtime.
enum DeviceClass {
  /// Android TV with <= 1 GB RAM.
  tvLow,

  /// Android TV with > 1 GB RAM.
  tvMid,

  /// Mobile device with <= 2 GB RAM.
  mobileLow,

  /// Mobile device with <= 4 GB RAM.
  mobileMid,

  /// Mobile device with > 4 GB RAM.
  mobileHigh,

  /// Desktop (macOS, Linux, Windows).
  desktop;

  /// Detect the device class using platform checks and a RAM heuristic.
  ///
  /// [totalRamBytes] can be injected for testing; when `null` the method
  /// falls back to a conservative mid-tier default for each platform.
  factory DeviceClass.detect({int? totalRamBytes}) {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      // Android TV runs on Linux but is identified via the Android embedding.
      // Pure desktop platforms always get the desktop tier.
      return DeviceClass.desktop;
    }

    // Android or iOS (Flutter mobile).
    //
    // When RAM information is unavailable we default to mobileMid which gives
    // a safe middle-ground budget.
    if (totalRamBytes == null) {
      return DeviceClass.mobileMid;
    }

    final totalRamMB = totalRamBytes ~/ (1024 * 1024);

    if (totalRamMB <= 2048) return DeviceClass.mobileLow;
    if (totalRamMB <= 4096) return DeviceClass.mobileMid;
    return DeviceClass.mobileHigh;
  }

  /// Detect the device class for an Android TV device.
  ///
  /// Separated from [detect] because the TV/mobile distinction cannot be
  /// determined from `dart:io` alone and must come from the platform channel.
  factory DeviceClass.detectTV({int? totalRamBytes}) {
    if (totalRamBytes == null) return DeviceClass.tvMid;

    final totalRamMB = totalRamBytes ~/ (1024 * 1024);
    return totalRamMB <= 1024 ? DeviceClass.tvLow : DeviceClass.tvMid;
  }
}
