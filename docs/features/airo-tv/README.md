# Airo TV Planning Index

Airo TV is the v2 media-product direction for Airo: a bring-your-own-content
IPTV and personal media hub that uses AI, device profiles, and companion
devices to improve discovery and playback without providing content.

## Documents

- [PRD_SOURCE_v2.0.0.1.md](./PRD_SOURCE_v2.0.0.1.md): raw pasted source material saved from the clipboard attachment.
- [AIRO_TV_DEVICE_GUIDE.md](./AIRO_TV_DEVICE_GUIDE.md): device setup guide, tutorial structure, troubleshooting, and current/planned feature status for Airo TV v2.
- [V2_0_0_1_PLAN.md](./V2_0_0_1_PLAN.md): recommended release plan and scope for the v2.0.0.1 planning milestone.
- [V2_0_0_1_REQUIREMENTS_REVIEW.md](./V2_0_0_1_REQUIREMENTS_REVIEW.md): requirement inventory, disposition, risks, and open questions.
- [V2_0_0_1_GAP_ANALYSIS.md](./V2_0_0_1_GAP_ANALYSIS.md): static gap analysis between the core PRD, current repository state, and implementation readiness.
- [VOLUME_2_GAP_ANALYSIS.md](./VOLUME_2_GAP_ANALYSIS.md): gap analysis for Volume 2, covering universal media sources, metadata, search, import, health, EPG, and smart infrastructure.
- [VOLUME_3_GAP_ANALYSIS.md](./VOLUME_3_GAP_ANALYSIS.md): gap analysis for Volume 3, covering connected-device architecture, local discovery, secure pairing, playback abstraction, sync, AI routing, and cross-platform Flutter requirements.
- [VOLUME_4_GAP_ANALYSIS.md](./VOLUME_4_GAP_ANALYSIS.md): gap analysis for Volume 4, covering the Media Routing Engine, playback delegation, route selection, secure last-resort phone streaming, smart buffering, ownership, and Edge Media Node readiness.
- [VOLUME_5_GAP_ANALYSIS.md](./VOLUME_5_GAP_ANALYSIS.md): gap analysis for Volume 5, covering native media engine architecture, scalable data infrastructure, local protocol, background workers, performance budgets, and constrained-device readiness.
- [VOLUME_6_GAP_ANALYSIS.md](./VOLUME_6_GAP_ANALYSIS.md): gap analysis for Volume 6, covering optional cloud playback orchestration, device presence, command routing, universal session state, secure playback tickets, remote control, and continuity.
- [VOLUME_7_GAP_ANALYSIS.md](./VOLUME_7_GAP_ANALYSIS.md): gap analysis for Volume 7, covering legacy Android TV support, API 26 baseline policy, constrained hardware modes, dependency governance, Legacy Receiver Mode, restricted trust, and device certification.
- [VOLUME_8_GAP_ANALYSIS.md](./VOLUME_8_GAP_ANALYSIS.md): gap analysis for Volume 8, covering modular product profiles, build-time composition, capability contracts, delegation, remote views, profile-specific navigation, release channels, and cross-profile testing.
- [VOLUME_9_GAP_ANALYSIS.md](./VOLUME_9_GAP_ANALYSIS.md): gap analysis for Volume 9, covering privacy-safe analytics, playback quality telemetry, consent, schema governance, crash redaction, experimentation, dashboards, alerts, and diagnostics.
- [V2_0_0_1_FEATURE_PACKET.md](./V2_0_0_1_FEATURE_PACKET.md): agent-policy packet with ownership, contracts, deterministic use cases, and automation flows.

## GitHub Execution

- Release tracker: https://github.com/DevelopersCoffee/airo/issues/672
- Milestone: `v2.0.0.1 - Airo TV Platform Hardening`
- Backlog: `ATV-001` through `ATV-081` are open as GitHub issues under the release milestone and added to the Airo Engineering Board.

## Release-Line Note

The repository release policy uses immutable semantic v2 tags such as
`v2.0.0`, `v2.0.1`, and `v2.1.0`. These docs keep the requested label
`v2.0.0.1` only as the Airo TV platform-hardening planning milestone name.
Do not publish four-part Git release tags such as `v2.0.0.1` for this
workstream unless `docs/release/VERSION_LINES.md` is deliberately changed by
Release and DevEx. Release candidates and public releases are tagged from `v2`
with the next normal semantic v2 version. The active next development stream
uses branch `codex/next-v2.0.0.0` from latest `origin/main`; release candidates
and public tags are cut from `v2` after the issue-scoped work merges back.
