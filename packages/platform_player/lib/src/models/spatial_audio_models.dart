import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'playback_engine_models.dart';

const String kAiroSpatialAudioSchemaVersion = '1.0.0';

/// User-facing audio output mode for Aika Stream Spatial Mode (v1).
///
/// [original] is the default: decoded PCM reaches the device unchanged.
/// [spatial] routes PCM through the post-decode processor chain (identity
/// passthrough in this spike; binaural DSP lands in #2082).
enum AiroSpatialAudioMode {
  original('original'),
  spatial('spatial');

  const AiroSpatialAudioMode(this.stableId);

  final String stableId;

  static AiroSpatialAudioMode? fromStableId(String? stableId) {
    if (stableId == null) return null;
    for (final mode in AiroSpatialAudioMode.values) {
      if (mode.stableId == stableId) return mode;
    }
    return null;
  }
}

/// Where (or if) decoded PCM can be observed before the platform audio sink.
enum AiroSpatialAudioTapKind {
  /// PCM is visible in an [AudioProcessor] / equivalent hook after decode.
  pcmAfterDecode('pcm_after_decode'),

  /// Playback works but the active backend exposes no PCM hook (e.g. stock
  /// `video_player` → ExoPlayer without a custom `DefaultAudioSink`).
  opaqueBackend('opaque_backend'),

  /// No native implementation on this host/flavor (stub plugin, web, etc.).
  unavailable('unavailable');

  const AiroSpatialAudioTapKind(this.stableId);

  final String stableId;

  static AiroSpatialAudioTapKind? fromStableId(String? stableId) {
    if (stableId == null) return null;
    for (final kind in AiroSpatialAudioTapKind.values) {
      if (kind.stableId == stableId) return kind;
    }
    return null;
  }
}

/// Fixed PCM layout for the v1 spatial processor contract (stereo/mono IPTV).
enum AiroPcmSampleEncoding {
  pcm16LittleEndian('pcm16_le');

  const AiroPcmSampleEncoding(this.stableId);

  final String stableId;
}

/// One decoded PCM buffer crossing the spatial tap (framework contract only).
class AiroPcmAudioBuffer extends Equatable {
  AiroPcmAudioBuffer({
    required this.sampleRateHz,
    required this.channelCount,
    required this.encoding,
    required Uint8List samples,
    this.presentationTimeUs,
    this.schemaVersion = kAiroSpatialAudioSchemaVersion,
  }) : samples = Uint8List.fromList(samples);

  final String schemaVersion;
  final int sampleRateHz;
  final int channelCount;
  final AiroPcmSampleEncoding encoding;
  final Uint8List samples;

  /// Optional presentation timestamp in microseconds (Media3-shaped).
  final int? presentationTimeUs;

  int get frameCount {
    final bytesPerSample = encoding == AiroPcmSampleEncoding.pcm16LittleEndian
        ? 2
        : 0;
    if (bytesPerSample == 0 || channelCount == 0) return 0;
    return samples.lengthInBytes ~/ (bytesPerSample * channelCount);
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    sampleRateHz,
    channelCount,
    encoding,
    samples,
    presentationTimeUs,
  ];
}

/// Capability report for a running or candidate playback backend.
class AiroSpatialAudioTapStatus extends Equatable {
  AiroSpatialAudioTapStatus({
    required this.backendKind,
    required this.tapKind,
    this.detailCodes = const [],
    this.processorInstalled = false,
    this.framesProcessed = 0,
    this.schemaVersion = kAiroSpatialAudioSchemaVersion,
  });

  final String schemaVersion;
  final AiroPlaybackBackendKind backendKind;
  final AiroSpatialAudioTapKind tapKind;
  final List<String> detailCodes;
  final bool processorInstalled;

  /// Diagnostic counter from identity passthrough (native or in-process fake).
  final int framesProcessed;

  bool get isTapActive => tapKind == AiroSpatialAudioTapKind.pcmAfterDecode;

  @override
  List<Object?> get props => [
    schemaVersion,
    backendKind,
    tapKind,
    detailCodes,
    processorInstalled,
    framesProcessed,
  ];
}
