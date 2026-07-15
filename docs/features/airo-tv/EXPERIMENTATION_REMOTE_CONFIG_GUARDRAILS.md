# Experimentation And Remote Config Guardrails

Issue: ATV-078
Package: `core_experimentation`
Layer: Platform framework, consumed by Airo TV app and release code

## Purpose

Experimentation and remote-config guardrails define how Airo TV can assign
anonymous subjects to variants, evaluate remote flags, apply kill switches, and
block unsafe overrides without coupling feature code to a provider SDK. Airo TV
app code consumes evaluated decisions; it must not let remote config bypass
privacy, security, entitlement, release, or build-composition boundaries.

## Ownership

- Framework owns typed experiment, flag, subject, kill-switch, decision, and
  evaluator models.
- Security owns non-overridable privacy, security, entitlement, and
  build-composition guardrails.
- Release owns release-channel, minimum-version, rollout, and kill-switch
  eligibility.
- QA owns deterministic assignment, kill-switch, eligibility, unsafe override,
  and public-map tests.
- Airo TV app code owns runtime wiring, settings/education UI, and
  product-specific decision consumption.

## Platform Contract

`AiroExperimentSubject` carries anonymous assignment metadata:

- stable assignment key;
- product profile;
- release channel;
- app version;
- region bucket;
- enabled module ids;
- entitlement ids.

Public subject maps intentionally omit the assignment key. Raw user ids,
emails, provider payloads, local-network data, credentials, device logs, and
diagnostic dumps must not be serialized.

`AiroExperimentDefinition` defines:

- experiment id;
- variants with basis-point weights;
- eligible product profiles, release channels, and region buckets;
- required modules and entitlements;
- minimum app version;
- rollout basis points;
- enabled/disabled state.

`AiroRemoteConfigFlag` defines the same eligibility surface plus requested
override kinds. Overrides for privacy consent, security controls, entitlements,
build composition, release channel, and minimum version are always blocked by
platform guardrail codes.

`AiroExperimentKillSwitchRegistry` blocks target ids before rollout or variant
selection.

## Evaluation Rules

`AiroExperimentEvaluator` evaluates in deterministic order:

1. disabled state and kill switch;
2. product profile;
3. release channel;
4. minimum app version;
5. region bucket;
6. rollout bucket;
7. required modules;
8. required entitlements;
9. unsafe remote-config override kinds.

Experiment assignment uses a stable hash of the anonymous assignment key and
target id. Decisions expose only the target id, variant id, assignment bucket,
and guardrail codes.

## Automation

- Unit tests prove repeated assignment gives the same variant for the same
  anonymous subject.
- Unit tests prove kill switches block an experiment regardless of rollout.
- Unit tests prove remote config cannot enable absent modules or request
  privacy, security, entitlement, or build-composition overrides.
- Unit tests prove profile, channel, app version, region, and rollout checks
  return deterministic codes.
- Public-map tests verify raw assignment keys and unsafe network, credential,
  provider, and local diagnostic values are not exposed.

## Deferred Work

Provider SDK adapters, server-side assignment persistence, admin tooling,
dashboard alerts, runtime Airo TV wiring, and user-facing settings/education UI
remain separate issues.
