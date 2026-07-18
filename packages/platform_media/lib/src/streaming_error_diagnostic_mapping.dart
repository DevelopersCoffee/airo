import 'dart:async';

import 'package:platform_player/platform_player.dart';

/// Maps a raw playback exception/message from [VideoPlayerController] or the
/// streaming service (CV-001) to a stable, user-safe [AiroPlaybackDiagnostic].
///
/// `video_player` and its platform channels surface failures as opaque
/// exceptions/strings rather than typed HTTP status codes, so this applies
/// best-effort pattern matching before falling back to
/// [AiroPlaybackDiagnosticCode.unknown]. The raw message is never included
/// in [AiroPlaybackDiagnostic.technicalDetail] since it may embed the stream
/// URL (and therefore credentials).
AiroPlaybackDiagnostic mapStreamingErrorToDiagnostic(Object error) {
  const mapper = AiroPlaybackDiagnosticMapper();

  if (error is TimeoutException) {
    return mapper.map(
      const AiroPlaybackFailureEvent(
        overrideCode: AiroPlaybackDiagnosticCode.networkUnavailable,
      ),
    );
  }

  final message = error.toString().toLowerCase();

  if (_containsCodecSignal(message)) {
    return mapper.map(
      const AiroPlaybackFailureEvent(
        overrideCode: AiroPlaybackDiagnosticCode.codecUnsupported,
      ),
    );
  }

  final status = _firstHttpStatus(message);
  if (status != null) {
    return mapper.map(AiroPlaybackFailureEvent(httpStatusCode: status));
  }

  return mapper.map(
    const AiroPlaybackFailureEvent(
      overrideCode: AiroPlaybackDiagnosticCode.unknown,
    ),
  );
}

bool _containsCodecSignal(String message) {
  return message.contains('codec') || message.contains('unsupported format');
}

final _httpStatusPattern = RegExp(r'\b([1-5][0-9]{2})\b');

int? _firstHttpStatus(String message) {
  for (final match in _httpStatusPattern.allMatches(message)) {
    final value = int.tryParse(match.group(1)!);
    if (value != null && value >= 400 && value < 600) return value;
  }
  return null;
}
