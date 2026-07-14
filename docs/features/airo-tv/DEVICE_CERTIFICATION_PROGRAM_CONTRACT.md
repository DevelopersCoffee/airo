# Airo TV Device Certification Program Contract

This contract defines the v2.0.0.1 platform program layer for Airo TV device
certification. It evaluates a set of target device classes against the legacy
certification matrix and produces the support claims release tooling may
advertise.

Implementation contract:

- Package: `packages/platform_certification`
- Schema: `kAiroCertificationSchemaVersion`
- Matrix: `AiroTvLegacyCertification.matrix()`
- Program input: `AiroCertificationProgram`
- Program output: `AiroCertificationProgramReport`

## Ownership Boundary

Device certification is platform/release behavior. QA automation and device-lab
runs provide `AiroCertificationEvidence`; platform code evaluates that evidence
against stable target and gate contracts; release tooling consumes the program
report before publishing support claims. Airo TV application code must not infer
Certified, Compatible, Experimental, or Unsupported status from app screens or
runtime heuristics.

## Program Report

The program report contains:

- program id;
- release line;
- certification matrix schema version;
- per-target certification results;
- blocked target ids;
- stable blocker codes;
- advertised support claims for targets that passed and can be advertised;
- creation and generation timestamps.

The public report must not include raw evidence logs, local workspace paths,
machine names, screenshots, or diagnostic dumps.

## Required Use Cases

- Complete fresh evidence for API 26, API 28, and Fire TV legacy targets
  returns Certified/Compatible support claims.
- Missing or stale evidence blocks only the affected target while preserving
  support claims for targets with passing evidence.
- Unsupported lower-API targets stay blocked and cannot advertise support.
- Empty target lists are deterministic and pass only because no target was
  requested.
- Single-target matrix evaluation remains backward-compatible for current
  certification callers.
