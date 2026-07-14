# Platform Media

Reusable media platform contracts and adapters for Airo products.

This package owns playback-adjacent platform behavior that should not be
hard-coded inside product screens. Airo TV, route selection, QA automation, and
future native media adapters consume these contracts through stable interfaces.

## Scope

- Video-player based IPTV streaming service.
- Privacy-filtered platform media analytics logging.
- Versioned media capability requirement and device profile models.
- Deterministic media capability preflight blocker codes for codec, container,
  HDR, bitrate, resolution, subtitles, audio, adaptive streaming, and decoder
  kind.
- Fake and no-op media capability detectors for automation and integration
  boundaries.
- Shared media error taxonomy for category, severity, retryability, stable user
  message keys, safe context refs, and redacted diagnostic handles.

This package does not perform native decoder probing yet, inspect raw media
files, own route selection, localize user-facing copy, upload analytics, export
support bundles, or decide Airo TV product UX. Native adapters should plug in
behind `AiroMediaCapabilityDetector`, and backend-specific failures should map
into `AiroMediaErrorClassifier`.

## Usage

```dart
final profile = AiroMediaDeviceCapabilityProfile(
  profileId: 'receiver-lite',
  observedAt: DateTime.utc(2026, 7, 14),
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
    AiroAudioDecoderCapability(codec: AiroAudioCodec.aac, maxChannelCount: 2),
  ],
  subtitleFormats: const {AiroSubtitleFormat.webVtt},
);

final result = const AiroMediaCapabilityPolicy().validate(
  profile: profile,
  requirement: AiroMediaRequirement(
    mediaId: 'episode-1',
    container: AiroMediaContainer.hls,
    videoCodec: AiroVideoCodec.h264,
    audioCodecs: const {AiroAudioCodec.aac},
    subtitleFormats: const {AiroSubtitleFormat.webVtt},
    width: 1280,
    height: 720,
    bitrateKbps: 4500,
    requiresAdaptiveStreaming: true,
  ),
);
```

Diagnostics expose normalized ids and blocker codes, not source handles, local
paths, addresses, or unique hardware identifiers.
