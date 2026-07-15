# ADR-002: Memory budgets per device class

## Status

Accepted

## Date

2026-07-15

## Context

Airo runs on a wide spectrum of hardware: Android TV boxes with as little as
1 GB RAM, budget phones with 2 GB, mid-range phones with 4 GB, high-end
phones with 8+ GB, and desktop machines with effectively unlimited memory.

A single set of cache/list limits either wastes memory on high-end devices or
causes OOM kills on low-end ones. The image cache, in-memory channel list,
and overall RSS footprint are the three main memory consumers that need
per-device tuning.

Additionally, storage patterns vary in overhead. SharedPreferences serializes
the entire file on every write and is unsuitable for anything larger than
small config values. Hive has known corruption issues under concurrent access
and is being phased out.

## Decision

### Device classes

Introduce a `DeviceClass` enum with six tiers:

| Class        | RAM heuristic   | Example hardware            |
| ------------ | --------------- | --------------------------- |
| `tvLow`      | TV, <= 1 GB     | Fire TV Stick Lite          |
| `tvMid`      | TV, > 1 GB      | Chromecast w/ Google TV     |
| `mobileLow`  | Mobile, <= 2 GB | Galaxy A03, Redmi A1        |
| `mobileMid`  | Mobile, <= 4 GB | Pixel 6a, Galaxy A14        |
| `mobileHigh` | Mobile, > 4 GB  | Pixel 8 Pro, iPhone 15      |
| `desktop`    | Any desktop OS  | macOS, Linux, Windows       |

### Memory budgets

Each device class gets a `MemoryBudget` with five constraints:

| Parameter          | tvLow  | tvMid  | mobLow | mobMid | mobHigh | desktop |
| ------------------ | ------ | ------ | ------ | ------ | ------- | ------- |
| imageCacheBytes    | 30 MB  | 50 MB  | 30 MB  | 80 MB  | 100 MB  | 200 MB  |
| imageCacheCount    | 100    | 200    | 150    | 300    | 500     | 1000    |
| maxChannelListSize | 5 000  | 20 000 | 5 000  | 20 000 | 50 000  | 100 000 |
| rssTargetBytes     | 200 MB | 300 MB | 150 MB | 250 MB | 400 MB  | 800 MB  |
| rssPeakBytes       | 300 MB | 450 MB | 250 MB | 400 MB | 600 MB  | 1200 MB |

### Storage policy tiers

| Data size / type    | Storage layer       | Rationale                                    |
| ------------------- | ------------------- | -------------------------------------------- |
| Prefs < 64 KB       | SharedPreferences   | Fast, atomic, platform-native                |
| Structured records  | SQLite (sqflite)    | ACID, indexed queries, no corruption issues  |
| Files / blobs       | path_provider dirs  | File-system backed, OS-managed lifecycle     |

### Hive deprecation

Hive is deprecated and must not be used in new code. Existing Hive usage
should be migrated to SQLite or SharedPreferences as files are touched.

## Consequences

### Positive

- Low-end devices stay within OS memory limits and avoid LMK (low memory
  killer) termination.
- High-end devices and desktop fully utilize available memory for smoother UX.
- A single `MemoryBudget.forDevice()` call replaces scattered magic numbers.
- Storage policy prevents SharedPreferences bloat (the root cause of several
  past ANRs).

### Negative

- Device class detection requires a platform channel on Android to distinguish
  TV from mobile; on other platforms the `dart:io` check is sufficient.
- The RAM heuristic is approximate; borderline devices may land in a
  sub-optimal tier.

### Risks

- If RAM reporting is unavailable at startup (e.g., permissions), the fallback
  to `mobileMid` / `tvMid` may be too generous for the lowest-end hardware.

## Alternatives Considered

### Alternative 1: Single adaptive cache with dynamic resizing

Dynamically resize caches based on runtime memory pressure signals.

Rejected because Android's `onTrimMemory` callbacks are unreliable on TV
devices, and reactive resizing causes visible jank when large caches are
evicted mid-scroll.

### Alternative 2: Two-tier (low / high) split

Simpler but loses the TV-specific constraints which are the primary
motivation. TV devices have unique display and input characteristics that
warrant their own tier.

## Related Decisions

- [ADR-0001](0001-package-structure.md) - Package structure

## References

- Issue #778: Performance benchmark harness + CI budgets
- Issue #779: Memory budgets per device class
