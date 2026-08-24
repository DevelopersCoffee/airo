import 'package:flutter/foundation.dart';

/// Whether live STT preview is supported on this host (ADR-0025 / fan-out §Web).
///
/// Desktop: one `record.startStream` ingest into native `CaptureFanout`
/// (file + live worker). Web and mobile native fan-out are not on the
/// contract path yet — live modes are gated off.
bool liveTranscriptionPreviewSupported({TargetPlatform? platform}) {
  if (kIsWeb) return false;
  final host = platform ?? defaultTargetPlatform;
  return host == TargetPlatform.macOS ||
      host == TargetPlatform.linux ||
      host == TargetPlatform.windows;
}

/// Hosts where live modes are hidden but users may still need guidance copy.
bool liveTranscriptionMobileHost({TargetPlatform? platform}) {
  if (kIsWeb) return false;
  final host = platform ?? defaultTargetPlatform;
  return host == TargetPlatform.android || host == TargetPlatform.iOS;
}

/// User-facing note when live preview is unavailable on this host.
String liveTranscriptionUnavailableMessage({TargetPlatform? platform}) {
  if (kIsWeb) {
    return 'Live transcription is not available on web. Use After recording.';
  }
  if (liveTranscriptionMobileHost(platform: platform)) {
    return 'Live transcription preview is desktop-only for now. '
        'Use After recording on phone and tablet.';
  }
  return 'Live transcription is not available on this device. '
      'Use After recording.';
}

/// Preview disclaimer shown in settings when live modes are selectable.
const String liveTranscriptionPreviewDisclaimer =
    'Preview on desktop: live transcript is provisional; speaker labels may '
    'change; best results with Live + refine.';
