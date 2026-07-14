# Airo TV Runtime Legacy Device Profile Contract

This contract defines the v2.0.0.1 platform boundary for runtime device
profiling, legacy-device support tier classification, and dynamic
reclassification into Legacy Receiver Mode.

Implementation contract:

- Package: `packages/platform_device_profile`
- Schema: `kAiroRuntimeDeviceProfileSchemaVersion`
- Primary policy: `AiroRuntimeDeviceProfilePolicy`
- Profiler boundary: `AiroRuntimeDeviceProfiler`

## Ownership Boundary

Runtime device profiling is platform/framework behavior. Airo TV app code may
consume profile decisions to choose navigation, feature visibility, settings
copy, and compatibility messaging, but it must not hard-code runtime support
tiers in app screens.

The contract composes existing platform contracts:

- `product_capabilities` for static product profiles, product support levels,
  and baseline media codec vocabulary;
- `core_protocol` for platform category vocabulary.

## Runtime Signals

The runtime profile records bucketed, privacy-safe signals:

- Android API level;
- platform category;
- RAM and free storage buckets;
- GPU class;
- decoder count and decoder failure count;
- baseline media codec support;
- network class;
- remote input capability;
- thermal pressure;
- secure storage availability;
- security patch age bucket.

It must not persist device serials, MAC addresses, advertising IDs, raw model
fingerprints, local IP addresses, credentials, provider payloads, or diagnostics
dumps.

## Classification Rules

`AiroRuntimeDeviceProfilePolicy` returns a deterministic profile with:

- support tier: fully supported, legacy optimized, experimental, unsupported;
- recommended product profile: Full TV, Lite Receiver, Experimental Legacy, or
  Embedded Receiver;
- Legacy Receiver Mode recommendation;
- restricted receiver trust recommendation;
- stable constraint codes.

Classification is capability-based, not OS-version-only. Dynamic pressure from
memory, storage, thermal, network, and decoder failures can force a device into
Legacy Receiver Mode even if its first-launch profile looked stronger.

## Required Use Cases

- API 26+ constrained TVs with baseline codecs classify as Legacy Optimized /
  Lite Receiver.
- Strong TVs with baseline codecs classify as Fully Supported / Full TV.
- API below baseline, missing secure storage, missing D-pad, or missing baseline
  codecs are unsupported or experimental according to policy.
- Runtime pressure can reclassify a device into Legacy Receiver Mode.
- Fake and no-op profilers are available for deterministic host-side tests.
