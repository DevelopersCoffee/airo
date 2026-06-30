# Memory Baseline (PFR-1)

*Note: The goal of this baseline is repeatability rather than optimization. Measurements are taken in Profile mode post-bootstrap.*

## Snapshot Measurements
- **Startup Heap**: ~28 MB
- **Platform Object Count**: ~14,000 objects (Dart VM base + Platform Services)
- **Provider Count**: 6 global platform providers
- **Bootstrap Allocations**: Peak of 2 MB transient allocations during DAG resolution.

*Memory regressions in Program 1 (e.g. holding onto large LLM models) will be measured against this base shell footprint.*
