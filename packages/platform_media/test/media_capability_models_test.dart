import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';

void main() {
  group('AiroMediaCapabilityPolicy', () {
    const policy = AiroMediaCapabilityPolicy();
    final now = DateTime.utc(2026, 7, 14, 12);

    AiroMediaDeviceCapabilityProfile profile({
      Set<AiroMediaContainer> containers = const {
        AiroMediaContainer.hls,
        AiroMediaContainer.mp4,
        AiroMediaContainer.mpegTs,
      },
      List<AiroVideoDecoderCapability>? videoDecoders,
      List<AiroAudioDecoderCapability> audioDecoders = const [
        AiroAudioDecoderCapability(
          codec: AiroAudioCodec.aac,
          maxChannelCount: 2,
        ),
        AiroAudioDecoderCapability(
          codec: AiroAudioCodec.ac3,
          maxChannelCount: 6,
          supportsPassthrough: true,
        ),
      ],
      Set<AiroSubtitleFormat> subtitleFormats = const {
        AiroSubtitleFormat.webVtt,
        AiroSubtitleFormat.cea608,
      },
      bool supportsAdaptiveStreaming = true,
    }) {
      return AiroMediaDeviceCapabilityProfile(
        profileId: 'receiver-1',
        observedAt: now,
        supportedContainers: containers,
        supportsAdaptiveStreaming: supportsAdaptiveStreaming,
        videoDecoders:
            videoDecoders ??
            [
              AiroVideoDecoderCapability(
                codec: AiroVideoCodec.h264,
                kind: AiroMediaDecoderKind.hardware,
                maxWidth: 1920,
                maxHeight: 1080,
                maxBitrateKbps: 8000,
                hdrFormats: const {AiroHdrFormat.sdr},
              ),
              AiroVideoDecoderCapability(
                codec: AiroVideoCodec.h265,
                kind: AiroMediaDecoderKind.software,
                maxWidth: 1280,
                maxHeight: 720,
                maxBitrateKbps: 3000,
                hdrFormats: const {AiroHdrFormat.sdr},
              ),
            ],
        audioDecoders: audioDecoders,
        subtitleFormats: subtitleFormats,
      );
    }

    AiroMediaRequirement requirement({
      AiroMediaContainer container = AiroMediaContainer.hls,
      AiroVideoCodec videoCodec = AiroVideoCodec.h264,
      Set<AiroAudioCodec> audioCodecs = const {AiroAudioCodec.aac},
      Set<AiroSubtitleFormat> subtitleFormats = const {
        AiroSubtitleFormat.webVtt,
      },
      AiroHdrFormat hdrFormat = AiroHdrFormat.sdr,
      int width = 1280,
      int height = 720,
      int bitrateKbps = 4500,
      int frameRate = 30,
      int audioChannelCount = 2,
      bool requiresAdaptiveStreaming = true,
      bool requiresHardwareDecoder = false,
    }) {
      return AiroMediaRequirement(
        mediaId: 'media-1',
        container: container,
        videoCodec: videoCodec,
        audioCodecs: audioCodecs,
        subtitleFormats: subtitleFormats,
        hdrFormat: hdrFormat,
        width: width,
        height: height,
        bitrateKbps: bitrateKbps,
        frameRate: frameRate,
        audioChannelCount: audioChannelCount,
        requiresAdaptiveStreaming: requiresAdaptiveStreaming,
        requiresHardwareDecoder: requiresHardwareDecoder,
      );
    }

    test('accepts baseline HLS media when receiver capabilities match', () {
      final result = policy.validate(
        profile: profile(),
        requirement: requirement(),
      );

      expect(result.accepted, isTrue);
      expect(result.selectedDecoderKind, AiroMediaDecoderKind.hardware);
    });

    test('rejects unsupported container video audio and subtitles', () {
      final result = policy.validate(
        profile: profile(),
        requirement: requirement(
          container: AiroMediaContainer.matroska,
          videoCodec: AiroVideoCodec.av1,
          audioCodecs: const {AiroAudioCodec.opus},
          subtitleFormats: const {AiroSubtitleFormat.srt},
        ),
      );

      expect(
        result.blockers,
        contains(AiroMediaCapabilityBlockerCode.containerUnsupported),
      );
      expect(
        result.blockers,
        contains(AiroMediaCapabilityBlockerCode.videoCodecUnsupported),
      );
      expect(
        result.blockers,
        contains(AiroMediaCapabilityBlockerCode.audioCodecUnsupported),
      );
      expect(
        result.blockers,
        contains(AiroMediaCapabilityBlockerCode.subtitleUnsupported),
      );
    });

    test(
      'rejects bitrate resolution frame rate and HDR beyond decoder limits',
      () {
        final result = policy.validate(
          profile: profile(),
          requirement: requirement(
            width: 3840,
            height: 2160,
            bitrateKbps: 18000,
            frameRate: 120,
            hdrFormat: AiroHdrFormat.hdr10,
          ),
        );

        expect(
          result.blockers,
          contains(AiroMediaCapabilityBlockerCode.resolutionTooHigh),
        );
        expect(
          result.blockers,
          contains(AiroMediaCapabilityBlockerCode.bitrateTooHigh),
        );
        expect(
          result.blockers,
          contains(AiroMediaCapabilityBlockerCode.frameRateTooHigh),
        );
        expect(
          result.blockers,
          contains(AiroMediaCapabilityBlockerCode.hdrUnsupported),
        );
      },
    );

    test(
      'rejects software-only decoder when hardware decoding is required',
      () {
        final result = policy.validate(
          profile: profile(),
          requirement: requirement(
            videoCodec: AiroVideoCodec.h265,
            bitrateKbps: 2500,
            requiresHardwareDecoder: true,
            requiresAdaptiveStreaming: false,
          ),
        );

        expect(
          result.blockers,
          contains(AiroMediaCapabilityBlockerCode.hardwareDecoderRequired),
        );
      },
    );

    test(
      'rejects hardware requirement when only software meets media limits',
      () {
        final result = policy.validate(
          profile: profile(
            videoDecoders: [
              AiroVideoDecoderCapability(
                codec: AiroVideoCodec.h265,
                kind: AiroMediaDecoderKind.hardware,
                maxWidth: 640,
                maxHeight: 360,
                maxBitrateKbps: 1000,
                hdrFormats: const {AiroHdrFormat.sdr},
              ),
              AiroVideoDecoderCapability(
                codec: AiroVideoCodec.h265,
                kind: AiroMediaDecoderKind.software,
                maxWidth: 1920,
                maxHeight: 1080,
                maxBitrateKbps: 8000,
                hdrFormats: const {AiroHdrFormat.sdr},
              ),
            ],
          ),
          requirement: requirement(
            videoCodec: AiroVideoCodec.h265,
            requiresHardwareDecoder: true,
            requiresAdaptiveStreaming: false,
          ),
        );

        expect(
          result.blockers,
          contains(AiroMediaCapabilityBlockerCode.hardwareDecoderRequired),
        );
      },
    );

    test('rejects missing adaptive streaming and high audio channel count', () {
      final result = policy.validate(
        profile: profile(supportsAdaptiveStreaming: false),
        requirement: requirement(audioChannelCount: 8),
      );

      expect(
        result.blockers,
        contains(AiroMediaCapabilityBlockerCode.adaptiveStreamingRequired),
      );
      expect(
        result.blockers,
        contains(AiroMediaCapabilityBlockerCode.audioChannelCountTooHigh),
      );
    });

    test('unavailable profile returns stable unavailable blocker', () {
      final result = policy.validate(
        profile: AiroMediaDeviceCapabilityProfile.unavailable(observedAt: now),
        requirement: requirement(),
      );

      expect(
        result.blockers,
        contains(AiroMediaCapabilityBlockerCode.profileUnavailable),
      );
      expect(result.accepted, isFalse);
    });

    test('diagnostics do not expose raw source values or device details', () {
      final deviceProfile = profile();
      final mediaRequirement = requirement();
      final result = policy.validate(
        profile: deviceProfile,
        requirement: mediaRequirement,
      );

      expect(deviceProfile.toString(), isNot(contains('sdk')));
      expect(mediaRequirement.toString(), isNot(contains('http')));
      expect(result.toString(), contains('accepted'));
    });
  });

  group('AiroMediaCapabilityDetector adapters', () {
    final now = DateTime.utc(2026, 7, 14, 12);

    final requirement = AiroMediaRequirement(
      mediaId: 'media-1',
      container: AiroMediaContainer.hls,
      videoCodec: AiroVideoCodec.h264,
      audioCodecs: const {AiroAudioCodec.aac},
      subtitleFormats: const {AiroSubtitleFormat.webVtt},
      width: 1280,
      height: 720,
      bitrateKbps: 4500,
      requiresAdaptiveStreaming: true,
    );

    final profile = AiroMediaDeviceCapabilityProfile(
      profileId: 'receiver-1',
      observedAt: now,
      supportedContainers: const {AiroMediaContainer.hls},
      supportsAdaptiveStreaming: true,
      videoDecoders: [
        AiroVideoDecoderCapability(
          codec: AiroVideoCodec.h264,
          kind: AiroMediaDecoderKind.hardware,
          maxWidth: 1920,
          maxHeight: 1080,
          maxBitrateKbps: 8000,
          hdrFormats: const {AiroHdrFormat.sdr},
        ),
      ],
      audioDecoders: const [
        AiroAudioDecoderCapability(
          codec: AiroAudioCodec.aac,
          maxChannelCount: 2,
        ),
      ],
      subtitleFormats: const {AiroSubtitleFormat.webVtt},
    );

    test('no-op detector reports unavailable without native probing', () async {
      const detector = AiroNoOpMediaCapabilityDetector();

      final currentProfile = await Future.value(detector.currentProfile());
      final result = await Future.value(detector.preflight(requirement));

      expect(currentProfile.isAvailable, isFalse);
      expect(
        result.blockers,
        contains(AiroMediaCapabilityBlockerCode.profileUnavailable),
      );
    });

    test(
      'fake detector returns deterministic profile and preflight result',
      () async {
        final detector = AiroFakeMediaCapabilityDetector(profile: profile);

        final currentProfile = await Future.value(detector.currentProfile());
        final result = await Future.value(detector.preflight(requirement));

        expect(currentProfile.profileId, 'receiver-1');
        expect(result.accepted, isTrue);
        expect(result.selectedDecoderKind, AiroMediaDecoderKind.hardware);
      },
    );
  });
}
