# Airo TV Media Decoder Probe Matrix Contract

This contract defines the v2.0.0.1 platform probe matrix for Airo TV media
capability and decoder support. It turns a normalized media device capability
profile into required baseline pass/fail results and optional advanced support
claims.

Implementation contract:

- Package: `packages/platform_media`
- Schema: `kAiroMediaCapabilitySchemaVersion`
- Matrix: `AiroMediaDecoderProbeMatrices.legacyReceiverBaseline()`
- Input: `AiroMediaDeviceCapabilityProfile`
- Output: `AiroMediaProbeMatrixReport`

## Ownership Boundary

Media capability probing is platform/framework behavior. QA and platform
adapters may populate `AiroMediaDeviceCapabilityProfile` from native probe
evidence. Airo TV app code may consume the report for playback fallback,
compatibility copy, and feature visibility, but it must not hard-code decoder,
HDR, HEVC, AV1, or 4K support in screens.

## Required Baseline Probes

The baseline matrix requires:

- HLS H.264/AAC with hardware decoding;
- MP4 H.264/AAC with hardware decoding;
- MPEG-TS H.264/AAC with hardware decoding;
- WebVTT subtitle support on the HLS baseline.

If any required probe fails, the receiver cannot claim baseline media
compatibility for Lite Receiver or legacy Airo TV profiles.

## Optional Advanced Probes

Advanced probes are not required for baseline support. They can only be
advertised when the probe passes:

- HEVC 1080p SDR;
- AV1 1080p SDR;
- HDR10 HEVC 1080p;
- H.264 4K SDR.

## Report Rules

The report contains required-pass state, blocked required probes, all blocked
probe ids, proven optional probe ids, and stable media capability blocker codes.
The public report must not include raw stream URLs, local file paths, network
addresses, unique device identifiers, or native diagnostic dumps.
