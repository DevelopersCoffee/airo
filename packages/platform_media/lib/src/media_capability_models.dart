import 'dart:async';

import 'package:platform_player/platform_player.dart';

const String kAiroMediaCapabilitySchemaVersion = '1.0.0';

enum AiroMediaContainer {
  hls('hls'),
  dash('dash'),
  mp4('mp4'),
  mpegTs('mpeg_ts'),
  matroska('matroska'),
  unknown('unknown');

  const AiroMediaContainer(this.stableId);

  final String stableId;
}

enum AiroVideoCodec {
  h264('h264'),
  h265('h265'),
  av1('av1'),
  vp9('vp9'),
  mpeg2('mpeg2'),
  unknown('unknown');

  const AiroVideoCodec(this.stableId);

  final String stableId;
}

enum AiroAudioCodec {
  aac('aac'),
  ac3('ac3'),
  eac3('eac3'),
  mp3('mp3'),
  opus('opus'),
  pcm('pcm'),
  unknown('unknown');

  const AiroAudioCodec(this.stableId);

  final String stableId;
}

enum AiroHdrFormat {
  sdr('sdr'),
  hdr10('hdr10'),
  hdr10Plus('hdr10_plus'),
  dolbyVision('dolby_vision'),
  hlg('hlg'),
  unknown('unknown');

  const AiroHdrFormat(this.stableId);

  final String stableId;
}

enum AiroSubtitleFormat {
  none('none'),
  webVtt('web_vtt'),
  srt('srt'),
  cea608('cea_608'),
  ttml('ttml'),
  imageBased('image_based'),
  unknown('unknown');

  const AiroSubtitleFormat(this.stableId);

  final String stableId;
}

enum AiroMediaDecoderKind {
  hardware('hardware'),
  software('software'),
  hybrid('hybrid'),
  unknown('unknown');

  const AiroMediaDecoderKind(this.stableId);

  final String stableId;
}

enum AiroMediaCapabilityBlockerCode {
  accepted('accepted'),
  profileUnavailable('profile_unavailable'),
  containerUnsupported('container_unsupported'),
  adaptiveStreamingRequired('adaptive_streaming_required'),
  videoCodecUnsupported('video_codec_unsupported'),
  hardwareDecoderRequired('hardware_decoder_required'),
  resolutionTooHigh('resolution_too_high'),
  bitrateTooHigh('bitrate_too_high'),
  frameRateTooHigh('frame_rate_too_high'),
  hdrUnsupported('hdr_unsupported'),
  audioCodecUnsupported('audio_codec_unsupported'),
  audioChannelCountTooHigh('audio_channel_count_too_high'),
  subtitleUnsupported('subtitle_unsupported');

  const AiroMediaCapabilityBlockerCode(this.stableId);

  final String stableId;
}

enum AiroMediaProbeId {
  baselineHlsH264Aac('baseline_hls_h264_aac'),
  baselineMp4H264Aac('baseline_mp4_h264_aac'),
  baselineMpegTsH264Aac('baseline_mpeg_ts_h264_aac'),
  baselineWebVttSubtitles('baseline_web_vtt_subtitles'),
  hevc1080pSdr('hevc_1080p_sdr'),
  av11080pSdr('av1_1080p_sdr'),
  hdr10Hevc1080p('hdr10_hevc_1080p'),
  h2644kSdr('h264_4k_sdr');

  const AiroMediaProbeId(this.stableId);

  final String stableId;
}

enum AiroMediaProbeImportance {
  required('required'),
  optional('optional');

  const AiroMediaProbeImportance(this.stableId);

  final String stableId;
}

class AiroMediaRequirement {
  AiroMediaRequirement({
    required this.mediaId,
    required this.container,
    required this.videoCodec,
    required Set<AiroAudioCodec> audioCodecs,
    required Set<AiroSubtitleFormat> subtitleFormats,
    required this.width,
    required this.height,
    required this.bitrateKbps,
    this.hdrFormat = AiroHdrFormat.sdr,
    this.frameRate = 30,
    this.audioChannelCount = 2,
    this.requiresAdaptiveStreaming = false,
    this.requiresHardwareDecoder = false,
    this.schemaVersion = kAiroMediaCapabilitySchemaVersion,
  }) : audioCodecs = Set.unmodifiable(audioCodecs),
       subtitleFormats = Set.unmodifiable(subtitleFormats),
       assert(width > 0),
       assert(height > 0),
       assert(bitrateKbps > 0),
       assert(frameRate > 0),
       assert(audioChannelCount > 0);

  final String schemaVersion;
  final String mediaId;
  final AiroMediaContainer container;
  final AiroVideoCodec videoCodec;
  final Set<AiroAudioCodec> audioCodecs;
  final Set<AiroSubtitleFormat> subtitleFormats;
  final int width;
  final int height;
  final int bitrateKbps;
  final AiroHdrFormat hdrFormat;
  final int frameRate;
  final int audioChannelCount;
  final bool requiresAdaptiveStreaming;
  final bool requiresHardwareDecoder;

  @override
  String toString() {
    return 'AiroMediaRequirement('
        'mediaId: $mediaId, '
        'container: ${container.stableId}, '
        'videoCodec: ${videoCodec.stableId}, '
        'audioCodecs: ${audioCodecs.map((codec) => codec.stableId).toList()}, '
        'subtitleFormats: ${subtitleFormats.map((format) => format.stableId).toList()}, '
        'resolution: ${width}x$height, '
        'bitrateKbps: $bitrateKbps, '
        'hdrFormat: ${hdrFormat.stableId}'
        ')';
  }
}

class AiroVideoDecoderCapability {
  AiroVideoDecoderCapability({
    required this.codec,
    required this.kind,
    required this.maxWidth,
    required this.maxHeight,
    required this.maxBitrateKbps,
    required Set<AiroHdrFormat> hdrFormats,
    this.maxFrameRate = 60,
  }) : hdrFormats = Set.unmodifiable(hdrFormats),
       assert(maxWidth > 0),
       assert(maxHeight > 0),
       assert(maxBitrateKbps > 0),
       assert(maxFrameRate > 0);

  final AiroVideoCodec codec;
  final AiroMediaDecoderKind kind;
  final int maxWidth;
  final int maxHeight;
  final int maxBitrateKbps;
  final int maxFrameRate;
  final Set<AiroHdrFormat> hdrFormats;

  bool get isHardwareAccelerated =>
      kind == AiroMediaDecoderKind.hardware ||
      kind == AiroMediaDecoderKind.hybrid;

  bool canDecode(AiroMediaRequirement requirement) {
    return codec == requirement.videoCodec &&
        maxWidth >= requirement.width &&
        maxHeight >= requirement.height &&
        maxBitrateKbps >= requirement.bitrateKbps &&
        maxFrameRate >= requirement.frameRate &&
        hdrFormats.contains(requirement.hdrFormat);
  }
}

class AiroAudioDecoderCapability {
  const AiroAudioDecoderCapability({
    required this.codec,
    required this.maxChannelCount,
    this.supportsPassthrough = false,
  }) : assert(maxChannelCount > 0);

  final AiroAudioCodec codec;
  final int maxChannelCount;
  final bool supportsPassthrough;

  bool canDecode(AiroAudioCodec requiredCodec, int requiredChannelCount) {
    return codec == requiredCodec && maxChannelCount >= requiredChannelCount;
  }
}

class AiroMediaDeviceCapabilityProfile {
  AiroMediaDeviceCapabilityProfile({
    required this.profileId,
    required this.observedAt,
    required Set<AiroMediaContainer> supportedContainers,
    required List<AiroVideoDecoderCapability> videoDecoders,
    required List<AiroAudioDecoderCapability> audioDecoders,
    required Set<AiroSubtitleFormat> subtitleFormats,
    this.supportsAdaptiveStreaming = false,
    this.isAvailable = true,
    this.schemaVersion = kAiroMediaCapabilitySchemaVersion,
  }) : supportedContainers = Set.unmodifiable(supportedContainers),
       videoDecoders = List.unmodifiable(videoDecoders),
       audioDecoders = List.unmodifiable(audioDecoders),
       subtitleFormats = Set.unmodifiable(subtitleFormats);

  AiroMediaDeviceCapabilityProfile.unavailable({
    required this.observedAt,
    this.profileId = 'unavailable',
    this.schemaVersion = kAiroMediaCapabilitySchemaVersion,
  }) : supportedContainers = const {},
       videoDecoders = const [],
       audioDecoders = const [],
       subtitleFormats = const {},
       supportsAdaptiveStreaming = false,
       isAvailable = false;

  final String schemaVersion;
  final String profileId;
  final DateTime observedAt;
  final Set<AiroMediaContainer> supportedContainers;
  final List<AiroVideoDecoderCapability> videoDecoders;
  final List<AiroAudioDecoderCapability> audioDecoders;
  final Set<AiroSubtitleFormat> subtitleFormats;
  final bool supportsAdaptiveStreaming;
  final bool isAvailable;

  AiroVideoDecoderCapability? bestVideoDecoderFor(
    AiroMediaRequirement requirement,
  ) {
    final matching =
        videoDecoders
            .where((decoder) => decoder.canDecode(requirement))
            .toList()
          ..sort((left, right) {
            final hardwareRank = right.isHardwareAccelerated
                .toString()
                .compareTo(left.isHardwareAccelerated.toString());
            if (hardwareRank != 0) return hardwareRank;
            return left.kind.stableId.compareTo(right.kind.stableId);
          });
    return matching.isEmpty ? null : matching.first;
  }

  bool supportsAllSubtitles(Set<AiroSubtitleFormat> requiredFormats) =>
      subtitleFormats.containsAll(requiredFormats);

  @override
  String toString() {
    return 'AiroMediaDeviceCapabilityProfile('
        'profileId: $profileId, '
        'isAvailable: $isAvailable, '
        'containers: ${supportedContainers.map((container) => container.stableId).toList()}, '
        'videoCodecs: ${videoDecoders.map((decoder) => decoder.codec.stableId).toSet().toList()}, '
        'audioCodecs: ${audioDecoders.map((decoder) => decoder.codec.stableId).toSet().toList()}, '
        'subtitleFormats: ${subtitleFormats.map((format) => format.stableId).toList()}'
        ')';
  }
}

class AiroMediaCapabilityPreflightResult {
  AiroMediaCapabilityPreflightResult({
    required this.profileId,
    required this.mediaId,
    required List<AiroMediaCapabilityBlockerCode> blockers,
    this.selectedDecoderKind,
  }) : blockers = List.unmodifiable(blockers);

  final String profileId;
  final String mediaId;
  final List<AiroMediaCapabilityBlockerCode> blockers;
  final AiroMediaDecoderKind? selectedDecoderKind;

  bool get accepted =>
      blockers.length == 1 &&
      blockers.single == AiroMediaCapabilityBlockerCode.accepted;

  @override
  String toString() {
    return 'AiroMediaCapabilityPreflightResult('
        'profileId: $profileId, '
        'mediaId: $mediaId, '
        'blockers: ${blockers.map((blocker) => blocker.stableId).toList()}, '
        'selectedDecoderKind: ${selectedDecoderKind?.stableId}'
        ')';
  }
}

class AiroMediaCapabilityPolicy {
  const AiroMediaCapabilityPolicy();

  AiroMediaCapabilityPreflightResult validate({
    required AiroMediaDeviceCapabilityProfile profile,
    required AiroMediaRequirement requirement,
  }) {
    final blockers = <AiroMediaCapabilityBlockerCode>[];
    if (!profile.isAvailable) {
      blockers.add(AiroMediaCapabilityBlockerCode.profileUnavailable);
    }
    if (!profile.supportedContainers.contains(requirement.container)) {
      blockers.add(AiroMediaCapabilityBlockerCode.containerUnsupported);
    }
    if (requirement.requiresAdaptiveStreaming &&
        !profile.supportsAdaptiveStreaming) {
      blockers.add(AiroMediaCapabilityBlockerCode.adaptiveStreamingRequired);
    }

    final videoDecoders = profile.videoDecoders
        .where((decoder) => decoder.codec == requirement.videoCodec)
        .toList();
    final selectedVideoDecoder = profile.bestVideoDecoderFor(requirement);
    if (videoDecoders.isEmpty) {
      blockers.add(AiroMediaCapabilityBlockerCode.videoCodecUnsupported);
    } else {
      _addVideoLimitBlockers(
        requirement,
        videoDecoders,
        selectedVideoDecoder,
        blockers,
      );
    }

    _addAudioBlockers(profile, requirement, blockers);
    if (!profile.supportsAllSubtitles(requirement.subtitleFormats)) {
      blockers.add(AiroMediaCapabilityBlockerCode.subtitleUnsupported);
    }

    return AiroMediaCapabilityPreflightResult(
      profileId: profile.profileId,
      mediaId: requirement.mediaId,
      selectedDecoderKind: selectedVideoDecoder?.kind,
      blockers: blockers.isEmpty
          ? const [AiroMediaCapabilityBlockerCode.accepted]
          : blockers,
    );
  }

  void _addVideoLimitBlockers(
    AiroMediaRequirement requirement,
    List<AiroVideoDecoderCapability> videoDecoders,
    AiroVideoDecoderCapability? selectedVideoDecoder,
    List<AiroMediaCapabilityBlockerCode> blockers,
  ) {
    if (requirement.requiresHardwareDecoder &&
        !videoDecoders.any(
          (decoder) =>
              decoder.isHardwareAccelerated && decoder.canDecode(requirement),
        )) {
      blockers.add(AiroMediaCapabilityBlockerCode.hardwareDecoderRequired);
    }
    if (!videoDecoders.any(
      (decoder) =>
          decoder.maxWidth >= requirement.width &&
          decoder.maxHeight >= requirement.height,
    )) {
      blockers.add(AiroMediaCapabilityBlockerCode.resolutionTooHigh);
    }
    if (!videoDecoders.any(
      (decoder) => decoder.maxBitrateKbps >= requirement.bitrateKbps,
    )) {
      blockers.add(AiroMediaCapabilityBlockerCode.bitrateTooHigh);
    }
    if (!videoDecoders.any(
      (decoder) => decoder.maxFrameRate >= requirement.frameRate,
    )) {
      blockers.add(AiroMediaCapabilityBlockerCode.frameRateTooHigh);
    }
    if (!videoDecoders.any(
      (decoder) => decoder.hdrFormats.contains(requirement.hdrFormat),
    )) {
      blockers.add(AiroMediaCapabilityBlockerCode.hdrUnsupported);
    }
    if (selectedVideoDecoder == null &&
        !blockers.contains(
          AiroMediaCapabilityBlockerCode.videoCodecUnsupported,
        )) {
      blockers.add(AiroMediaCapabilityBlockerCode.videoCodecUnsupported);
    }
  }

  void _addAudioBlockers(
    AiroMediaDeviceCapabilityProfile profile,
    AiroMediaRequirement requirement,
    List<AiroMediaCapabilityBlockerCode> blockers,
  ) {
    for (final audioCodec in requirement.audioCodecs) {
      final matching = profile.audioDecoders
          .where((decoder) => decoder.codec == audioCodec)
          .toList();
      if (matching.isEmpty) {
        blockers.add(AiroMediaCapabilityBlockerCode.audioCodecUnsupported);
        continue;
      }
      if (!matching.any(
        (decoder) => decoder.maxChannelCount >= requirement.audioChannelCount,
      )) {
        blockers.add(AiroMediaCapabilityBlockerCode.audioChannelCountTooHigh);
      }
    }
  }
}

class AiroMediaProbeDefinition {
  AiroMediaProbeDefinition({
    required this.probeId,
    required this.displayName,
    required this.importance,
    required this.requirement,
    this.schemaVersion = kAiroMediaCapabilitySchemaVersion,
  });

  final String schemaVersion;
  final AiroMediaProbeId probeId;
  final String displayName;
  final AiroMediaProbeImportance importance;
  final AiroMediaRequirement requirement;

  bool get isRequired => importance == AiroMediaProbeImportance.required;
}

class AiroMediaProbeResult {
  const AiroMediaProbeResult({
    required this.probeId,
    required this.importance,
    required this.preflight,
  });

  final AiroMediaProbeId probeId;
  final AiroMediaProbeImportance importance;
  final AiroMediaCapabilityPreflightResult preflight;

  bool get passed => preflight.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'probeId': probeId.stableId,
      'importance': importance.stableId,
      'passed': passed,
      'blockers': preflight.blockers
          .map((blocker) => blocker.stableId)
          .toList(growable: false),
      'selectedDecoderKind': preflight.selectedDecoderKind?.stableId,
    };
  }
}

class AiroMediaProbeMatrixReport {
  AiroMediaProbeMatrixReport({
    required this.profileId,
    required Iterable<AiroMediaProbeResult> results,
    required this.generatedAt,
    this.schemaVersion = kAiroMediaCapabilitySchemaVersion,
  }) : results = List.unmodifiable(results);

  final String schemaVersion;
  final String profileId;
  final List<AiroMediaProbeResult> results;
  final DateTime generatedAt;

  bool get requiredProbesPassed => results
      .where((result) => result.importance == AiroMediaProbeImportance.required)
      .every((result) => result.passed);

  List<AiroMediaProbeId> get blockedProbeIds {
    return List.unmodifiable(
      results.where((result) => !result.passed).map((result) => result.probeId),
    );
  }

  List<AiroMediaProbeId> get blockedRequiredProbeIds {
    return List.unmodifiable(
      results
          .where(
            (result) =>
                result.importance == AiroMediaProbeImportance.required &&
                !result.passed,
          )
          .map((result) => result.probeId),
    );
  }

  List<AiroMediaProbeId> get provenOptionalProbeIds {
    return List.unmodifiable(
      results
          .where(
            (result) =>
                result.importance == AiroMediaProbeImportance.optional &&
                result.passed,
          )
          .map((result) => result.probeId),
    );
  }

  Set<AiroMediaCapabilityBlockerCode> get blockerCodes {
    return Set.unmodifiable(
      results
          .where((result) => !result.passed)
          .expand((result) => result.preflight.blockers)
          .where(
            (blocker) => blocker != AiroMediaCapabilityBlockerCode.accepted,
          ),
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'requiredProbesPassed': requiredProbesPassed,
      'blockedProbeIds': blockedProbeIds
          .map((probeId) => probeId.stableId)
          .toList(growable: false),
      'blockedRequiredProbeIds': blockedRequiredProbeIds
          .map((probeId) => probeId.stableId)
          .toList(growable: false),
      'provenOptionalProbeIds': provenOptionalProbeIds
          .map((probeId) => probeId.stableId)
          .toList(growable: false),
      'blockerCodes': blockerCodes
          .map((blocker) => blocker.stableId)
          .toList(growable: false),
      'results': results
          .map((result) => result.toPublicMap())
          .toList(growable: false),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

class AiroMediaDecoderProbeMatrix {
  AiroMediaDecoderProbeMatrix({
    required Iterable<AiroMediaProbeDefinition> probes,
    this.policy = const AiroMediaCapabilityPolicy(),
    this.schemaVersion = kAiroMediaCapabilitySchemaVersion,
  }) : probes = List.unmodifiable(probes);

  final String schemaVersion;
  final List<AiroMediaProbeDefinition> probes;
  final AiroMediaCapabilityPolicy policy;

  AiroMediaProbeMatrixReport evaluate({
    required AiroMediaDeviceCapabilityProfile profile,
    required DateTime now,
  }) {
    final results = [
      for (final probe in probes)
        AiroMediaProbeResult(
          probeId: probe.probeId,
          importance: probe.importance,
          preflight: policy.validate(
            profile: profile,
            requirement: probe.requirement,
          ),
        ),
    ];

    return AiroMediaProbeMatrixReport(
      profileId: profile.profileId,
      results: results,
      generatedAt: now,
      schemaVersion: schemaVersion,
    );
  }
}

class AiroMediaDecoderProbeMatrices {
  const AiroMediaDecoderProbeMatrices._();

  static AiroMediaDecoderProbeMatrix legacyReceiverBaseline() {
    return AiroMediaDecoderProbeMatrix(
      probes: [
        AiroMediaProbeDefinition(
          probeId: AiroMediaProbeId.baselineHlsH264Aac,
          displayName: 'HLS H.264 AAC baseline',
          importance: AiroMediaProbeImportance.required,
          requirement: AiroMediaRequirement(
            mediaId: AiroMediaProbeId.baselineHlsH264Aac.stableId,
            container: AiroMediaContainer.hls,
            videoCodec: AiroVideoCodec.h264,
            audioCodecs: const {AiroAudioCodec.aac},
            subtitleFormats: const {},
            width: 1280,
            height: 720,
            bitrateKbps: 4500,
            requiresAdaptiveStreaming: true,
            requiresHardwareDecoder: true,
          ),
        ),
        AiroMediaProbeDefinition(
          probeId: AiroMediaProbeId.baselineMp4H264Aac,
          displayName: 'MP4 H.264 AAC baseline',
          importance: AiroMediaProbeImportance.required,
          requirement: AiroMediaRequirement(
            mediaId: AiroMediaProbeId.baselineMp4H264Aac.stableId,
            container: AiroMediaContainer.mp4,
            videoCodec: AiroVideoCodec.h264,
            audioCodecs: const {AiroAudioCodec.aac},
            subtitleFormats: const {},
            width: 1280,
            height: 720,
            bitrateKbps: 4500,
            requiresHardwareDecoder: true,
          ),
        ),
        AiroMediaProbeDefinition(
          probeId: AiroMediaProbeId.baselineMpegTsH264Aac,
          displayName: 'MPEG-TS H.264 AAC baseline',
          importance: AiroMediaProbeImportance.required,
          requirement: AiroMediaRequirement(
            mediaId: AiroMediaProbeId.baselineMpegTsH264Aac.stableId,
            container: AiroMediaContainer.mpegTs,
            videoCodec: AiroVideoCodec.h264,
            audioCodecs: const {AiroAudioCodec.aac},
            subtitleFormats: const {AiroSubtitleFormat.cea608},
            width: 1280,
            height: 720,
            bitrateKbps: 4500,
            requiresHardwareDecoder: true,
          ),
        ),
        AiroMediaProbeDefinition(
          probeId: AiroMediaProbeId.baselineWebVttSubtitles,
          displayName: 'WebVTT subtitle baseline',
          importance: AiroMediaProbeImportance.required,
          requirement: AiroMediaRequirement(
            mediaId: AiroMediaProbeId.baselineWebVttSubtitles.stableId,
            container: AiroMediaContainer.hls,
            videoCodec: AiroVideoCodec.h264,
            audioCodecs: const {AiroAudioCodec.aac},
            subtitleFormats: const {AiroSubtitleFormat.webVtt},
            width: 1280,
            height: 720,
            bitrateKbps: 4500,
            requiresAdaptiveStreaming: true,
            requiresHardwareDecoder: true,
          ),
        ),
        AiroMediaProbeDefinition(
          probeId: AiroMediaProbeId.hevc1080pSdr,
          displayName: 'HEVC 1080p SDR',
          importance: AiroMediaProbeImportance.optional,
          requirement: AiroMediaRequirement(
            mediaId: AiroMediaProbeId.hevc1080pSdr.stableId,
            container: AiroMediaContainer.hls,
            videoCodec: AiroVideoCodec.h265,
            audioCodecs: const {AiroAudioCodec.aac},
            subtitleFormats: const {},
            width: 1920,
            height: 1080,
            bitrateKbps: 8000,
            requiresAdaptiveStreaming: true,
            requiresHardwareDecoder: true,
          ),
        ),
        AiroMediaProbeDefinition(
          probeId: AiroMediaProbeId.av11080pSdr,
          displayName: 'AV1 1080p SDR',
          importance: AiroMediaProbeImportance.optional,
          requirement: AiroMediaRequirement(
            mediaId: AiroMediaProbeId.av11080pSdr.stableId,
            container: AiroMediaContainer.mp4,
            videoCodec: AiroVideoCodec.av1,
            audioCodecs: const {AiroAudioCodec.aac},
            subtitleFormats: const {},
            width: 1920,
            height: 1080,
            bitrateKbps: 8000,
            requiresHardwareDecoder: true,
          ),
        ),
        AiroMediaProbeDefinition(
          probeId: AiroMediaProbeId.hdr10Hevc1080p,
          displayName: 'HDR10 HEVC 1080p',
          importance: AiroMediaProbeImportance.optional,
          requirement: AiroMediaRequirement(
            mediaId: AiroMediaProbeId.hdr10Hevc1080p.stableId,
            container: AiroMediaContainer.hls,
            videoCodec: AiroVideoCodec.h265,
            audioCodecs: const {AiroAudioCodec.aac},
            subtitleFormats: const {},
            width: 1920,
            height: 1080,
            bitrateKbps: 10000,
            hdrFormat: AiroHdrFormat.hdr10,
            requiresAdaptiveStreaming: true,
            requiresHardwareDecoder: true,
          ),
        ),
        AiroMediaProbeDefinition(
          probeId: AiroMediaProbeId.h2644kSdr,
          displayName: 'H.264 4K SDR',
          importance: AiroMediaProbeImportance.optional,
          requirement: AiroMediaRequirement(
            mediaId: AiroMediaProbeId.h2644kSdr.stableId,
            container: AiroMediaContainer.mp4,
            videoCodec: AiroVideoCodec.h264,
            audioCodecs: const {AiroAudioCodec.aac},
            subtitleFormats: const {},
            width: 3840,
            height: 2160,
            bitrateKbps: 18000,
            requiresHardwareDecoder: true,
          ),
        ),
      ],
    );
  }
}

abstract interface class AiroMediaCapabilityDetector {
  FutureOr<AiroMediaDeviceCapabilityProfile> currentProfile();

  FutureOr<AiroMediaCapabilityPreflightResult> preflight(
    AiroMediaRequirement requirement,
  );
}

class AiroNoOpMediaCapabilityDetector implements AiroMediaCapabilityDetector {
  const AiroNoOpMediaCapabilityDetector({
    this.policy = const AiroMediaCapabilityPolicy(),
  });

  final AiroMediaCapabilityPolicy policy;

  @override
  FutureOr<AiroMediaDeviceCapabilityProfile> currentProfile() {
    return AiroMediaDeviceCapabilityProfile.unavailable(
      observedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  FutureOr<AiroMediaCapabilityPreflightResult> preflight(
    AiroMediaRequirement requirement,
  ) {
    return policy.validate(
      profile: AiroMediaDeviceCapabilityProfile.unavailable(
        observedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      requirement: requirement,
    );
  }
}

class AiroPictureInPictureCapability {
  const AiroPictureInPictureCapability._();

  static const Set<AiroPlaybackPlatform> _pictureInPicturePlatforms = {
    AiroPlaybackPlatform.androidMobile,
    AiroPlaybackPlatform.ios,
    AiroPlaybackPlatform.macos,
    AiroPlaybackPlatform.web,
  };

  static bool supports({
    required AiroPlaybackPlatform platform,
    required AiroPlaybackBackendKind engineKind,
  }) {
    return engineKind == AiroPlaybackBackendKind.videoPlayer &&
        _pictureInPicturePlatforms.contains(platform);
  }
}

class AiroFakeMediaCapabilityDetector implements AiroMediaCapabilityDetector {
  const AiroFakeMediaCapabilityDetector({
    required this.profile,
    this.policy = const AiroMediaCapabilityPolicy(),
  });

  final AiroMediaDeviceCapabilityProfile profile;
  final AiroMediaCapabilityPolicy policy;

  @override
  FutureOr<AiroMediaDeviceCapabilityProfile> currentProfile() => profile;

  @override
  FutureOr<AiroMediaCapabilityPreflightResult> preflight(
    AiroMediaRequirement requirement,
  ) {
    return policy.validate(profile: profile, requirement: requirement);
  }
}
