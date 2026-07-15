# Airo TV AI Search Delegation Contract

This contract defines the v2.0.0.1 platform boundary for future natural-language
and AI-assisted search. Lite Receiver and legacy Airo TV profiles must not
bundle heavyweight AI runtimes to expose search entry points. They should route
eligible work through a shared delegation contract.

Implementation contract:

- Package: `packages/core_ai_delegation`
- Schema: `kAiroAiDelegationSchemaVersion`
- Selector: `AiroAiDelegationSelector`
- No-op adapter: `AiroNoOpAiSearchDelegationProvider`

## Privacy Modes

| Mode | Eligible processing locations |
| --- | --- |
| `local_only` | On-device receiver only |
| `trusted_local_network` | Receiver, trusted companion, trusted home node |
| `cloud_allowed` | Receiver, trusted companion, trusted home node, cloud relay |

## Required Rules

- Search inputs use `AiroAiSearchInput`; string output is redacted.
- Empty, URL, local path, local IP, and credential-like inputs are rejected at
  the platform boundary.
- Delegation candidates must advertise processing location, capabilities, trust,
  availability, and estimated latency.
- Route decisions expose stable blocker codes instead of app-specific failure
  strings.
- Results disclose processing location and confidence bucket without logging raw
  search text.
- Companion, home-node, cloud, speech, model-runtime, and transport adapters are
  implementation details behind this contract.

## Release Rule

Natural-language search can be added to Airo TV without changing receiver
contracts only when consumers use `AiroAiDelegationRequest`,
`AiroAiDelegationCandidate`, `AiroAiDelegationSelector`, and
`AiroAiSearchResult`.

If no eligible delegate exists, Lite Receiver must remain usable with basic
search or explanatory fallback UI. Standalone playback cannot depend on
companion, home-node, cloud, or AI runtime availability.
