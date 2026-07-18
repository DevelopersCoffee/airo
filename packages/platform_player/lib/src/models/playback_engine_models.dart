import 'package:equatable/equatable.dart';

const String kAiroPlaybackEngineSchemaVersion = '1.0.0';

enum AiroPlaybackBackendKind {
  videoPlayer('video_player'),
  cast('cast'),
  media3('media3'),
  libVlc('lib_vlc'),
  mpv('mpv'),
  fake('fake'),
  unavailable('unavailable');

  const AiroPlaybackBackendKind(this.stableId);

  final String stableId;
}

enum AiroPlaybackMediaKind {
  hls('hls'),
  dash('dash'),
  progressive('progressive'),
  rtsp('rtsp'),
  file('file'),
  live('live'),
  protectedPlayback('protected_playback'),
  localPreview('local_preview');

  const AiroPlaybackMediaKind(this.stableId);

  final String stableId;
}

enum AiroPlaybackEnginePhase {
  idle('idle'),
  opening('opening'),
  open('open'),
  playing('playing'),
  paused('paused'),
  buffering('buffering'),
  seeking('seeking'),
  stopped('stopped'),
  ended('ended'),
  failed('failed'),
  unavailable('unavailable');

  const AiroPlaybackEnginePhase(this.stableId);

  final String stableId;
}

enum AiroPlaybackTrackKind {
  audio('audio'),
  subtitle('subtitle'),
  video('video');

  const AiroPlaybackTrackKind(this.stableId);

  final String stableId;
}

enum AiroPlaybackViewFit {
  contain('contain'),
  cover('cover'),
  fill('fill'),
  stretch('stretch');

  const AiroPlaybackViewFit(this.stableId);

  final String stableId;
}

enum AiroPlaybackSourceHandleRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroPlaybackSourceHandleRejectionCode(this.stableId);

  final String stableId;
}

enum AiroPlaybackErrorCode {
  backendUnavailable('backend_unavailable'),
  unsupportedOperation('unsupported_operation'),
  invalidSource('invalid_source'),
  sourceUnavailable('source_unavailable'),
  codecUnsupported('codec_unsupported'),
  protectedPlaybackUnsupported('protected_playback_unsupported'),
  networkUnavailable('network_unavailable'),
  decoderFailed('decoder_failed'),
  operationRejected('operation_rejected'),
  qualityUnavailable('quality_unavailable'),
  trackUnavailable('track_unavailable');

  const AiroPlaybackErrorCode(this.stableId);

  final String stableId;
}

class AiroPlaybackSourceHandle extends Equatable {
  const AiroPlaybackSourceHandle._(this.value);

  factory AiroPlaybackSourceHandle.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroPlaybackSourceHandle._(value.trim());
  }

  /// Accepts a trusted, internally-resolved playable URL (a channel or VOD
  /// stream URL from our own provider adapters) that `.redacted()` would
  /// reject — `.redacted()`'s URL-rejection check exists to catch raw user
  /// input passed by mistake, not legitimate stream URLs, which are always
  /// http/https and sometimes carry Xtream/Stalker credentials in the path.
  /// `toString()` still redacts: the safety invariant (never log/print the
  /// raw value) is unchanged, only the acceptance check is skipped.
  factory AiroPlaybackSourceHandle.direct(String url) {
    return AiroPlaybackSourceHandle._(url.trim());
  }

  final String value;

  static AiroPlaybackSourceHandleRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return AiroPlaybackSourceHandleRejectionCode.empty;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroPlaybackSourceHandleRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroPlaybackSourceHandleRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroPlaybackSourceHandleRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroPlaybackSourceHandleRejectionCode.credentialLikeValue;
    }

    return null;
  }

  @override
  String toString() => 'AiroPlaybackSourceHandle(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroPlaybackExternalSubtitle extends Equatable {
  const AiroPlaybackExternalSubtitle({
    required this.handle,
    this.languageCode,
    this.label,
  });

  final AiroPlaybackSourceHandle handle;
  final String? languageCode;
  final String? label;

  @override
  String toString() {
    return 'AiroPlaybackExternalSubtitle('
        'languageCode: $languageCode, '
        'label: $label, '
        'handle: redacted'
        ')';
  }

  @override
  List<Object?> get props => [handle, languageCode, label];
}

class AiroMediaOpenRequest extends Equatable {
  AiroMediaOpenRequest({
    required this.requestId,
    required this.sourceHandle,
    required this.mediaKind,
    this.startPosition = Duration.zero,
    this.preferredQualityId,
    List<AiroPlaybackExternalSubtitle> externalSubtitles = const [],
    this.schemaVersion = kAiroPlaybackEngineSchemaVersion,
  }) : externalSubtitles = List.unmodifiable(externalSubtitles);

  final String schemaVersion;
  final String requestId;
  final AiroPlaybackSourceHandle sourceHandle;
  final AiroPlaybackMediaKind mediaKind;
  final Duration startPosition;
  final String? preferredQualityId;
  final List<AiroPlaybackExternalSubtitle> externalSubtitles;

  @override
  String toString() {
    return 'AiroMediaOpenRequest('
        'requestId: $requestId, '
        'mediaKind: ${mediaKind.stableId}, '
        'startPosition: $startPosition, '
        'preferredQualityId: $preferredQualityId, '
        'externalSubtitleCount: ${externalSubtitles.length}, '
        'sourceHandle: redacted'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    sourceHandle,
    mediaKind,
    startPosition,
    preferredQualityId,
    externalSubtitles,
  ];
}

class AiroPlaybackQualityOption extends Equatable {
  const AiroPlaybackQualityOption({
    required this.id,
    required this.label,
    this.width,
    this.height,
    this.bitrateKbps,
  });

  final String id;
  final String label;
  final int? width;
  final int? height;
  final int? bitrateKbps;

  @override
  List<Object?> get props => [id, label, width, height, bitrateKbps];
}

class AiroPlaybackTrackOption extends Equatable {
  const AiroPlaybackTrackOption({
    required this.id,
    required this.kind,
    required this.label,
    this.languageCode,
    this.isExternal = false,
  });

  final String id;
  final AiroPlaybackTrackKind kind;
  final String label;
  final String? languageCode;

  /// True when the track was supplied by the caller via
  /// [AiroMediaOpenRequest.externalSubtitles] rather than probed from the
  /// media container itself. Lets the UI badge it distinctly.
  final bool isExternal;

  @override
  List<Object?> get props => [id, kind, label, languageCode, isExternal];
}

/// Stable id prefix for tracks projected from
/// [AiroMediaOpenRequest.externalSubtitles]. Engines use this so a
/// `selectTrack(subtitle, "external_sub_0")` call resolves deterministically
/// regardless of which engine is active — the mpv fallback swap must not
/// change track ids for the same open request.
const String kAiroExternalSubtitleTrackIdPrefix = 'external_sub_';

/// Projects the [AiroMediaOpenRequest.externalSubtitles] into a track catalog
/// entries list. Both concrete engine adapters call this on `open()` so an
/// external subtitle file passes through as a selectable track without any
/// engine-specific probing.
List<AiroPlaybackTrackOption> externalSubtitleTracksFor(
  AiroMediaOpenRequest request,
) {
  final entries = request.externalSubtitles;
  return List.unmodifiable(
    List<AiroPlaybackTrackOption>.generate(entries.length, (i) {
      final sub = entries[i];
      return AiroPlaybackTrackOption(
        id: '$kAiroExternalSubtitleTrackIdPrefix$i',
        kind: AiroPlaybackTrackKind.subtitle,
        label: sub.label ??
            sub.languageCode ??
            'External subtitle ${i + 1}',
        languageCode: sub.languageCode,
        isExternal: true,
      );
    }),
  );
}

class AiroPlaybackDiagnostics extends Equatable {
  AiroPlaybackDiagnostics({
    required this.backendId,
    List<String> detailCodes = const [],
    this.decoderName,
    this.codecName,
    this.hardwareAccelerated,
    this.droppedFrames,
    this.bufferedPosition,
  }) : detailCodes = List.unmodifiable(detailCodes);

  final String backendId;
  final String? decoderName;
  final String? codecName;
  final bool? hardwareAccelerated;
  final int? droppedFrames;
  final Duration? bufferedPosition;
  final List<String> detailCodes;

  @override
  String toString() {
    return 'AiroPlaybackDiagnostics('
        'backendId: $backendId, '
        'decoderName: $decoderName, '
        'codecName: $codecName, '
        'hardwareAccelerated: $hardwareAccelerated, '
        'droppedFrames: $droppedFrames, '
        'bufferedPosition: $bufferedPosition, '
        'detailCodes: $detailCodes'
        ')';
  }

  @override
  List<Object?> get props => [
    backendId,
    decoderName,
    codecName,
    hardwareAccelerated,
    droppedFrames,
    bufferedPosition,
    detailCodes,
  ];
}

class AiroPlaybackError extends Equatable {
  const AiroPlaybackError({required this.code, this.operation});

  final AiroPlaybackErrorCode code;
  final String? operation;

  @override
  List<Object?> get props => [code, operation];
}

class AiroPlaybackState extends Equatable {
  AiroPlaybackState({
    required this.backendKind,
    required this.phase,
    this.request,
    this.position = Duration.zero,
    this.duration,
    this.volume = 1,
    this.playbackSpeed = 1,
    List<AiroPlaybackQualityOption> qualityOptions = const [],
    this.selectedQualityId,
    List<AiroPlaybackTrackOption> tracks = const [],
    Map<AiroPlaybackTrackKind, String> selectedTrackIds = const {},
    this.diagnostics,
    this.error,
    this.schemaVersion = kAiroPlaybackEngineSchemaVersion,
  }) : qualityOptions = List.unmodifiable(qualityOptions),
       tracks = List.unmodifiable(tracks),
       selectedTrackIds = Map.unmodifiable(selectedTrackIds);

  factory AiroPlaybackState.idle({
    AiroPlaybackBackendKind backendKind = AiroPlaybackBackendKind.unavailable,
  }) {
    return AiroPlaybackState(
      backendKind: backendKind,
      phase: AiroPlaybackEnginePhase.idle,
    );
  }

  final String schemaVersion;
  final AiroPlaybackBackendKind backendKind;
  final AiroPlaybackEnginePhase phase;
  final AiroMediaOpenRequest? request;
  final Duration position;
  final Duration? duration;
  final double volume;
  final double playbackSpeed;
  final List<AiroPlaybackQualityOption> qualityOptions;
  final String? selectedQualityId;
  final List<AiroPlaybackTrackOption> tracks;
  final Map<AiroPlaybackTrackKind, String> selectedTrackIds;
  final AiroPlaybackDiagnostics? diagnostics;
  final AiroPlaybackError? error;

  AiroPlaybackState copyWith({
    AiroPlaybackEnginePhase? phase,
    AiroMediaOpenRequest? request,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackSpeed,
    List<AiroPlaybackQualityOption>? qualityOptions,
    String? selectedQualityId,
    List<AiroPlaybackTrackOption>? tracks,
    Map<AiroPlaybackTrackKind, String>? selectedTrackIds,
    AiroPlaybackDiagnostics? diagnostics,
    AiroPlaybackError? error,
  }) {
    return AiroPlaybackState(
      schemaVersion: schemaVersion,
      backendKind: backendKind,
      phase: phase ?? this.phase,
      request: request ?? this.request,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      qualityOptions: qualityOptions ?? this.qualityOptions,
      selectedQualityId: selectedQualityId ?? this.selectedQualityId,
      tracks: tracks ?? this.tracks,
      selectedTrackIds: selectedTrackIds ?? this.selectedTrackIds,
      diagnostics: diagnostics ?? this.diagnostics,
      error: error,
    );
  }

  @override
  String toString() {
    return 'AiroPlaybackState('
        'backendKind: ${backendKind.stableId}, '
        'phase: ${phase.stableId}, '
        'requestId: ${request?.requestId}, '
        'position: $position, '
        'duration: $duration, '
        'volume: $volume, '
        'playbackSpeed: $playbackSpeed, '
        'selectedQualityId: $selectedQualityId, '
        'selectedTrackIds: $selectedTrackIds, '
        'diagnostics: $diagnostics, '
        'error: $error'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    backendKind,
    phase,
    request,
    position,
    duration,
    volume,
    playbackSpeed,
    qualityOptions,
    selectedQualityId,
    tracks,
    selectedTrackIds,
    diagnostics,
    error,
  ];
}
