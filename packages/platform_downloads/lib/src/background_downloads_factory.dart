import 'package:flutter/foundation.dart';

import 'background_downloads.dart';
import 'http_background_downloads.dart';
import 'method_channel_background_downloads.dart';

/// Selects the download transport for the current host.
///
/// Android and iOS use the native progressive-download plugin. Desktop shells
/// (macOS, Linux, Windows) use a Dart [HttpBackgroundDownloads] fallback so
/// model acquisition does not throw [MissingPluginException].
BackgroundDownloads createBackgroundDownloads() {
  if (kIsWeb) {
    return HttpBackgroundDownloads();
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS =>
      MethodChannelBackgroundDownloads(),
    _ => HttpBackgroundDownloads(),
  };
}
