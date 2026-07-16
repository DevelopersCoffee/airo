---
name: Agent Task
about: Deferred community request
title: '[DEFERRED] CV-005: Local AI Media Layer and Semantic Voice Search'
labels: 'agent/ai-llm, agent/media, P2, enhancement, community-voice, v2-deferred'
assignees: ''
---

## V2 Milestone Decision

**Decision:** Defer from current v2.

**Reason:** Semantic voice search depends on the Offline LLM roadmap, local model registry, model routing, memory budgeting, ASR policy, and prompt/schema evaluation. Current v2 should ship deterministic local IPTV search first without requiring an LLM.

## What To Keep From The Community Request

- Natural language search is valuable after local search exists.
- The output should be structured filters, not free-form actions.
- Query execution should stay local by default.
- Latency, memory, and fallback behavior must be measured.
- Natural language setup for smart playlists is valuable later, e.g. "hide non-English channels", "remove adult", or "keep only sports", but it must compile into auditable local rules.

## What Not To Build In Current V2

- No Gemini Nano or GGUF integration for IPTV search.
- No model download or selection dependency.
- No semantic embeddings index.
- No voice activation flow beyond existing deterministic voice/search seams.
- No cloud LLM routing for media queries.
- No AI-generated smart playlist rules until deterministic CV-017 rules exist.

## Dependency

This request depends on the Offline LLM roadmap, especially:

- `.github/issues/offline-llm-01-model-registry.md`
- `.github/issues/offline-llm-04-dynamic-llm-routing.md`
- `.github/issues/offline-llm-05-memory-management.md`
- `.github/issues/offline-llm-07-fallback-strategies.md`

## Future Feature Packet Gate

**Problem:** Users need natural-language search and setup over local media metadata and smart playlist rules.
**User / actor:** User searching by voice/text on TV or mobile, or user asking Airo to create local filtering rules.
**Framework or application layer:** Mixed.
**Owning agent:** AI LLM Agent.
**Reviewing agents:** Media Agent, Framework Agent, Security and Privacy Agent, QA Automation Agent.
**Impacted modules/files:** `packages/core_ai`, `packages/platform_playlist`, `packages/platform_epg`, `packages/feature_iptv`.
**Base branch/worktree:** Must be reconfirmed from latest `origin/v2` when reopened.
**Open questions:** Approved local model, ASR dependency, schema, latency budget, no-model fallback.
**Decision:** Blocked until Offline LLM foundation is accepted.

## Future Cross-Agent Contract Required

**Provider agent:** AI LLM Agent.
**Consumer agent:** Media Agent.
**Interface/API:** Semantic media parser returning structured JSON filters or smart playlist rule drafts.
**Input shape:** User query text, optional locale, local metadata schema, allowed rule schema.
**Output shape:** Validated search/filter request or rule draft with confidence and fallback reason.
**State changes:** Optional local evaluation metrics.
**Errors:** No model, OOM guard, invalid JSON, low confidence, timeout.
**Permissions:** Microphone only for explicit voice input; no cloud model unless user opts in.
**Privacy/redaction:** Query stays local by default.
**Persistence:** Optional local metrics only.
**Versioning/migration:** Parser schema version required.
**Tests required:** Golden query set, no-model fallback, latency, invalid output recovery.

## Reopen Criteria

- Deterministic CV-006 local search is implemented.
- Deterministic CV-017 smart playlist rules are implemented before AI setup rules are attempted.
- Offline LLM routing and memory guardrails exist.
- A query schema and evaluation set are approved.
