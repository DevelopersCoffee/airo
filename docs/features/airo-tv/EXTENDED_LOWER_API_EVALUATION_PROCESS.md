# Extended Lower-API Evaluation Process

Issue: ATV-058
Package: `platform_certification`
Layer: Platform framework, consumed by Airo TV release and QA workflows

## Purpose

Airo TV starts legacy support at Android TV API 26. API 23-25 devices may be
evaluated only as internal experimental receiver candidates. They must not be
advertised as publicly supported until a future release deliberately changes
the certification and support policy.

This contract belongs in `platform_certification` because lower-API support is a
device certification and release-claim decision, not an Airo TV screen or
feature-module decision.

## Candidate Range

`AiroLowerApiEvaluationPolicy` evaluates candidates with:

- minimum Android API 23;
- maximum Android API 25;
- Lite Receiver product profile;
- internal or direct APK experimental release channel;
- no public support claim.

Out-of-range candidates are rejected with `api_range_unsupported`.

## Required Evidence

API 23-25 candidates require all of the following evidence before entering
internal experimental certification:

- dependency baseline;
- Flutter embedding compatibility;
- package-content scan;
- install and launch;
- remote focus;
- playback baseline;
- memory pressure;
- low storage;
- sleep/wake;
- restricted receiver trust;
- security patch review.

Missing, stale, or wrong-candidate evidence returns stable blocker codes.

## Public Support Rule

Any request to advertise API 23-25 as publicly supported is blocked with
`public_support_blocked`, even when all evidence exists. A complete evidence set
only allows internal experimental certification.

## Automation

- Unit tests assert accepted API 23-25 internal eligibility.
- Unit tests reject out-of-range candidates and public support claims.
- Unit tests cover missing, stale, and wrong-candidate evidence.
- Public-map tests verify no raw device logs, local paths, provider payloads, or
  private release material are exposed.
