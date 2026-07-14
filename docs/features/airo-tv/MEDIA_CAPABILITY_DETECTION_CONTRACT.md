# Media Capability Detection Contract

Status: v2 platform contract for ATV-024.

## Ownership

Media capability detection is platform/framework behavior. Airo TV consumes the
result to select routes, choose fallback media, and present product-specific UX,
but it must not hard-code codec or decoder assumptions in app screens.

The initial contract lives in `packages/platform_media` because it sits beside
playback-adjacent platform adapters and can later be consumed by media routing,
playback engines, device certification, and product profiles.

## Contract Shape

`AiroMediaRequirement` describes normalized media needs:

- container
- video codec
- audio codecs
- subtitle formats
- resolution
- bitrate
- frame rate
- HDR format
- adaptive streaming requirement
- hardware-decoder requirement

`AiroMediaDeviceCapabilityProfile` describes normalized receiver capability:

- supported containers
- video decoder capabilities
- audio decoder capabilities
- subtitle support
- adaptive streaming support
- profile availability

`AiroMediaCapabilityPolicy` returns stable blocker codes:

- `accepted`
- `profile_unavailable`
- `container_unsupported`
- `adaptive_streaming_required`
- `video_codec_unsupported`
- `hardware_decoder_required`
- `resolution_too_high`
- `bitrate_too_high`
- `frame_rate_too_high`
- `hdr_unsupported`
- `audio_codec_unsupported`
- `audio_channel_count_too_high`
- `subtitle_unsupported`

## Adapter Boundary

`AiroMediaCapabilityDetector` is the platform adapter interface. The package
includes:

- `AiroNoOpMediaCapabilityDetector` for products without native probing.
- `AiroFakeMediaCapabilityDetector` for deterministic QA and route-preflight
  tests.

No adapter in this issue imports native SDKs, reads media files, opens network
streams, or starts playback. Platform-specific probing must be implemented
behind this interface.

## Privacy And Diagnostics

Diagnostics expose normalized ids, capability categories, decoder kind, and
stable blocker codes. They must not expose raw stream URLs, local file paths,
network addresses, access material, or unique hardware identifiers.

## Deterministic Use Cases

- HLS or MP4 with H.264/AAC/SDR/WebVTT is accepted when receiver capabilities
  match the media requirement.
- AV1, HEVC, HDR, high bitrate, high resolution, or advanced subtitles are
  rejected unless the receiver profile explicitly supports them.
- A hardware-decoder-required requirement rejects software-only support.
- Missing adaptive streaming support rejects HLS/DASH paths that require it.
- No-op detection reports an unavailable profile with stable blocker codes.
- Fake detection returns deterministic profiles for QA automation.
