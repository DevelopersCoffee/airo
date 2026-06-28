/// Stub implementation of share_plus for TV builds
library;

/// Share result
class ShareResult {
  const ShareResult(this.raw, this.status);
  final String raw;
  final ShareResultStatus status;

  static const ShareResult unavailable = ShareResult(
    'unavailable',
    ShareResultStatus.unavailable,
  );
}

/// Share result status
enum ShareResultStatus { success, dismissed, unavailable }

class ShareParams {
  const ShareParams({
    this.text,
    this.subject,
    this.uri,
    this.files,
    this.sharePositionOrigin,
    this.fileNameOverrides,
    this.downloadFallbackEnabled,
  });

  final String? text;
  final String? subject;
  final Uri? uri;
  final List<dynamic>? files;
  final Rect? sharePositionOrigin;
  final List<String>? fileNameOverrides;
  final bool? downloadFallbackEnabled;
}

/// Stub SharePlus class - no sharing on TV
class SharePlus {
  const SharePlus._();
  static const SharePlus instance = SharePlus._();

  /// Share text - does nothing on TV
  Future<ShareResult> share(ShareParams params) async {
    return ShareResult.unavailable;
  }
}

/// Rect class for position origin
class Rect {
  const Rect.fromLTRB(this.left, this.top, this.right, this.bottom);

  factory Rect.fromLTWH(double left, double top, double width, double height) =>
      Rect.fromLTRB(left, top, left + width, top + height);
  final double left;
  final double top;
  final double right;
  final double bottom;
}
