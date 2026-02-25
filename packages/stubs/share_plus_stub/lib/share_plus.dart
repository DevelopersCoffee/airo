/// Stub implementation of share_plus for TV builds
library;

/// Share result
class ShareResult {
  final String raw;
  final ShareResultStatus status;
  
  const ShareResult(this.raw, this.status);
  
  static const ShareResult unavailable = ShareResult('unavailable', ShareResultStatus.unavailable);
}

/// Share result status
enum ShareResultStatus {
  success,
  dismissed,
  unavailable,
}

/// Stub Share class - no sharing on TV
class Share {
  /// Share text - does nothing on TV
  static Future<void> share(
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {}
  
  /// Share with result - returns unavailable on TV
  static Future<ShareResult> shareWithResult(
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async => ShareResult.unavailable;
  
  /// Share files - does nothing on TV
  static Future<void> shareFiles(
    List<String> paths, {
    List<String>? mimeTypes,
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) async {}
  
  /// Share files with result - returns unavailable on TV
  static Future<ShareResult> shareFilesWithResult(
    List<String> paths, {
    List<String>? mimeTypes,
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) async => ShareResult.unavailable;
  
  /// Share XFiles - does nothing on TV
  static Future<ShareResult> shareXFiles(
    List<dynamic> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) async => ShareResult.unavailable;
}

/// Rect class for position origin
class Rect {
  final double left;
  final double top;
  final double right;
  final double bottom;
  
  const Rect.fromLTRB(this.left, this.top, this.right, this.bottom);
  
  factory Rect.fromLTWH(double left, double top, double width, double height) {
    return Rect.fromLTRB(left, top, left + width, top + height);
  }
}

