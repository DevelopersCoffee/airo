---
name: Agent Task
about: Not adopted community request
title: '[NOT ADOPTED] CV-011: Airo Home Server and Docker Mode'
labels: 'agent/framework, P3, research, community-voice, v2-not-adopted'
assignees: ''
---

## V2 Milestone Decision

**Decision:** Do not adopt for current v2.

**Reason:** Docker/Home Server mode is a separate product line, not a v2 app milestone feature. It requires server packaging, network discovery, local API auth, update strategy, NAS/Raspberry Pi support, logs, support docs, security patching, and a different release/QA matrix.

## What To Keep As Future Research

- Some advanced users want one household cache for EPG, logos, and playlist processing.
- A future local server could reduce workload on low-end TV boxes.
- Any future design must be opt-in and private-by-default.

## What Not To Build In V2

- No `airo_server` crate.
- No Dockerfile or NAS packaging.
- No mDNS/SSDP server discovery.
- No local server sync protocol.
- No server-hosted playlist, EPG, proxy, or profile database.
- No issue/PR should implement this from the current community roadmap.

## Research Gate If Reopened Later

**Problem:** Determine whether a self-hosted Airo server is worth becoming a separate product.
**User / actor:** Advanced self-hosting user with NAS/Pi/Unraid.
**Framework or application layer:** New product surface.
**Owning agent:** Product/Framework Agent.
**Reviewing agents:** Security and Privacy Agent, Release and DevEx Agent, QA Automation Agent, Media Agent.
**Impacted modules/files:** New server workspace, `rust/airo_core`, network discovery packages, packaging docs.
**Base branch/worktree:** Must be separately planned; do not assume app `v2` branch is the right delivery vehicle.
**Open questions:** Business value, support burden, security model, update cadence, threat model, API auth, device discovery.
**Decision:** Blocked as implementation. Research only.

## Required Research Before Any Implementation

- Product brief with target user, support policy, and non-goals.
- Threat model for LAN server, playlist secrets, and profile data.
- Release plan for Docker images and CVE patching.
- API authentication model.
- QA matrix for amd64/arm64, NAS, Pi, and client discovery.
- Decision on whether this belongs in Airo TV or a separate repository/product.
