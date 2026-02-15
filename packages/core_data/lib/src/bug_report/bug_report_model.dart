import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Severity level for bug reports.
enum BugSeverity {
  low('Low', 'Minor issue, cosmetic or low impact', '🟢'),
  medium('Medium', 'Functional issue with workaround', '🟡'),
  high('High', 'Major issue affecting core functionality', '🟠'),
  critical('Critical', 'App crash or data loss', '🔴');

  const BugSeverity(this.label, this.description, this.emoji);
  final String label;
  final String description;
  final String emoji;

  String get githubLabel => 'severity:$name';
}

/// Category of the bug report.
enum BugCategory {
  crash('Crash', 'App crashes or freezes'),
  ui('UI/UX', 'Visual or interaction issues'),
  performance('Performance', 'Slow or laggy behavior'),
  feature('Feature', 'Feature not working as expected'),
  other('Other', 'Other issues');

  const BugCategory(this.label, this.description);
  final String label;
  final String description;

  String get githubLabel => 'category:$name';
}

/// Device and app information for bug reports.
class BugReportDeviceInfo {
  final String platform;
  final String osVersion;
  final String deviceModel;
  final String appVersion;
  final String buildNumber;
  final bool isDebugMode;
  final Map<String, dynamic> additionalInfo;

  const BugReportDeviceInfo({
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.appVersion,
    required this.buildNumber,
    required this.isDebugMode,
    this.additionalInfo = const {},
  });

  /// Creates device info for the current platform.
  factory BugReportDeviceInfo.current({
    required String appVersion,
    required String buildNumber,
    Map<String, dynamic>? additionalInfo,
  }) {
    return BugReportDeviceInfo(
      platform: _getCurrentPlatform(),
      osVersion: _getOsVersion(),
      deviceModel: _getDeviceModel(),
      appVersion: appVersion,
      buildNumber: buildNumber,
      isDebugMode: kDebugMode,
      additionalInfo: additionalInfo ?? {},
    );
  }

  static String _getCurrentPlatform() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  static String _getOsVersion() {
    if (kIsWeb) return 'Browser';
    return Platform.operatingSystemVersion;
  }

  static String _getDeviceModel() {
    if (kIsWeb) return 'Browser';
    // Will be populated from DeviceCapabilityService
    return 'Unknown';
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('| Property | Value |');
    buffer.writeln('|----------|-------|');
    buffer.writeln('| Platform | $platform |');
    buffer.writeln('| OS Version | $osVersion |');
    buffer.writeln('| Device Model | $deviceModel |');
    buffer.writeln('| App Version | $appVersion |');
    buffer.writeln('| Build Number | $buildNumber |');
    buffer.writeln('| Debug Mode | ${isDebugMode ? 'Yes' : 'No'} |');

    if (additionalInfo.isNotEmpty) {
      for (final entry in additionalInfo.entries) {
        buffer.writeln('| ${entry.key} | ${entry.value} |');
      }
    }

    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'osVersion': osVersion,
    'deviceModel': deviceModel,
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'isDebugMode': isDebugMode,
    ...additionalInfo,
  };
}

/// A bug report to be submitted to GitHub.
class BugReport {
  final String title;
  final String description;
  final BugSeverity severity;
  final BugCategory category;
  final BugReportDeviceInfo deviceInfo;
  final String? errorLogs;
  final String? stackTrace;
  final String? stepsToReproduce;
  final List<String>? screenshotPaths;

  /// Screenshot bytes for embedding directly in GitHub issues.
  /// This is preferred over screenshotPaths for cross-platform support.
  final Uint8List? screenshotBytes;

  final DateTime createdAt;

  BugReport({
    required this.title,
    required this.description,
    required this.severity,
    required this.category,
    required this.deviceInfo,
    this.errorLogs,
    this.stackTrace,
    this.stepsToReproduce,
    this.screenshotPaths,
    this.screenshotBytes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
