# Benchmark Device-Class Gates

Status: v2 platform contract for ATV-036.

## Ownership

Benchmark device-class gates are platform certification behavior. Airo TV,
Lite Receiver, companion apps, desktop companions, QA automation, release gates,
and future device-lab tooling consume this contract to decide whether a device
class can support advertised performance and compatibility claims.

The contract lives in `packages/platform_certification` because that package
already owns certification targets, validation matrices, evidence kinds, and
support-claim decisions. Benchmark runners, media database plans, telemetry, and
app UI remain separate consumers.

## Non-Goals

This issue does not implement:

- physical benchmark execution
- device-lab inventory
- CI uploads
- telemetry export
- playback execution
- import/search/EPG runners
- app UI
- store release submission

## Contract Shape

`AiroBenchmarkDeviceClassProfile` defines a device class by stable id, platform,
product profile, hardware floor, and required benchmark gates.

Default classes are:

- constrained TV
- standard TV
- mobile companion
- desktop companion

`AiroBenchmarkGate` defines a workload, accepted evidence kinds, physical-device
requirement, evidence freshness window, and metric thresholds.

Default workloads cover:

- startup latency
- scroll while import runs
- EPG refresh during playback
- remote control during playback
- protocol compatibility
- large playlist import
- search responsiveness
- cache cleanup

`AiroBenchmarkSample` records a redacted metric sample by stable sample id,
device class id, gate id, metric id, numeric value, evidence kind, and capture
time.

`AiroBenchmarkDeviceClassMatrix` evaluates samples and returns deterministic
blockers for missing classes, unsupported classes, missing gates, missing or
wrong samples, host-only evidence for physical gates, stale samples, unsafe ids,
and threshold failures.

`AiroBenchmarkEvidenceProvider` is the provider boundary. No-op providers return
no evidence. Fake providers return deterministic samples for host-side tests.

## Privacy

Benchmark profiles, gates, samples, and diagnostics expose only stable ids,
platform/profile classes, workload ids, metric ids, numeric thresholds, evidence
kinds, capture times, and blocker codes. They must not expose media URLs,
playlist URLs, EPG URLs, request headers, local paths, local addresses, provider
payloads, credentials, media titles, viewing history, analytics payloads, or
diagnostic dumps.

## Automation

- Unit tests evaluate default matrix classes with fixed clocks.
- Policy tests cover passing samples, missing evidence, stale evidence, wrong
  evidence kind, host-only evidence for physical gates, and threshold failures.
- Provider tests cover no-op and fake sample retrieval.
