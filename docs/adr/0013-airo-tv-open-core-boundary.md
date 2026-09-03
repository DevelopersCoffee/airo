# ADR 0013: Aika Stream open-core boundary

- Status: Accepted
- Date: 2026-07-27
- Decision owners: Product Manager, Chief Architect

## Context

Aika Stream must remain a complete self-hosted media player. Classification cannot
turn ordinary playback, accessibility, import, local data, or device support
into an upgrade prompt. Conversely, advanced intelligence and cross-device
services need an explicit commercial boundary.

## Decision

The decision rule is:

> Pro sells intelligence, sync, and enterprise outcomes; never basic playback.

Community Edition (`non-pro`) includes local playback and controls, casting,
user-supplied source import, parsing, EPG, accessibility, discovery, local
storage, export/backup, performance, device compatibility, and reusable
framework contracts.

Aika Stream Pro (`pro`) includes personalized intelligence, recommendation and
knowledge graphs, cross-device/cloud synchronization, enterprise identity or
management, licensed enrichment services, and advanced multi-feed/sports
workflows. Provider SDK adapters and private entitlement presentation stay
outside CE framework contracts.

An issue must carry exactly one classification. A mixed epic is classified
`pro` conservatively until CE and Pro deliverables are split into separately
labeled children. A reusable CE contract does not make a private capability
available, and a Pro adapter does not make the underlying player incomplete.

Classification is not a release claim. Open work is `Planned`; merged but
unqualified work is `Under qualification`; Aika Stream Pro remains `In testing`
until a public artifact and release evidence prove availability.

## Consequences

- Basic media use remains login-free and fully functional in CE.
- New issues must receive exactly one `pro` or `non-pro` label at creation.
- Product copy must use the public claim states and must not expose private
  repository, entitlement, billing, host, or credential details.
- Changing an issue's classification requires an ADR amendment or a linked
  decision comment explaining the boundary change.

## v0.0.5 audit

The milestone ledger is recorded in
[`V0_0_5_CE_PRO_CLASSIFICATION.md`](../release/V0_0_5_CE_PRO_CLASSIFICATION.md).
Every open milestone issue and every open CV tracking issue had exactly one
classification at the time of acceptance.
