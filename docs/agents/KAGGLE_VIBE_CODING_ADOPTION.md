# Kaggle Vibe-Coding Adoption Plan

> Date: 2026-06-23
> Scope: internal agent development process and Airo runtime framework

## Source Set

The Kaggle whitepaper pages are client-rendered, so static fetches expose page
titles and metadata but not the full paper body. This adoption plan is based on
the linked Kaggle paper topics, accessible public summaries, and the existing
Airo Brain, Agent Skills, Memory, Routine OS, and QA roadmap.

- The New SDLC With Vibe Coding:
  https://www.kaggle.com/whitepaper-the-new-SDLC-with-vibe-coding
- Agent Tools & Interoperability:
  https://www.kaggle.com/whitepaper-agent-tools-and-interoperability
- Agent Skills:
  https://www.kaggle.com/whitepaper-agent-skills
- Vibe Coding Agent Security and Evaluation:
  https://www.kaggle.com/whitepaper-vibe-coding-agent-security-and-evaluation
- Spec-Driven Production Grade Development in the Age of Vibe Coding:
  https://www.kaggle.com/whitepaper-spec-driven-production-grade-development-in-the-age-of-vibe-coding

## Adoption Summary

| Source | Internal Agent Coding Adoption | Airo Framework Adoption | Tracker |
| --- | --- | --- | --- |
| New SDLC with vibe coding | Treat AI as implementation acceleration only; keep requirements, architecture, review, and verification explicit. | Show every generated automation, skill, and routine as a traceable product artifact with ownership and tests. | #324 |
| Agent Tools & Interoperability | Use typed tool contracts, mocks, permission tiers, and trace assertions before coding tool flows. | Add MCP-compatible adapters, local tool registry, tool trust scopes, and long-running action states. | #326 |
| Agent Skills | Package agent procedure as small, triggered skills instead of large always-on prompts. | Support Google AI Edge-compatible skill packages, progressive disclosure, capability profiles, and skill-to-routine compilation. | #325 |
| Agent Security and Evaluation | Require adversarial prompts, sensitive-action checks, redaction, and review gates for AI/tool work. | Add security tiers for skills/routines, import validation, trace redaction, and eval suites for tool trajectories. | #326 |
| Spec-driven production-grade development | Require a Feature Packet before code: spec, contract, deterministic use cases, automation flow, eval plan, rollback. | Make routine packs, memory extractors, and tools schema-first with versioning, migrations, and reproducible tests. | #324 |

## Internal Coding Rules

Every implementation ticket must include a Feature Packet before code starts.

```markdown
## Feature Packet

**Problem:** ...
**Owner agent:** ...
**Review agents:** ...
**Framework/application boundary:** ...
**User-visible behavior:** ...
**Contract:** ...
**Deterministic use cases:** ...
**Automation flows:** ...
**Security/privacy posture:** ...
**Eval plan:** ...
**Observability/traces:** ...
**Rollback/migration plan:** ...
```

Implementation agents must not skip the Critical Agent Gate in
`AGENT_POLICY.md`. If a ticket is missing a contract or automation flow, the
correct next step is to add the missing spec, not to start code.

## Airo Framework Rules

### Skill and Routine Model

- A skill is procedural memory with metadata, instructions, optional resources,
  and optional executable assets.
- A capability profile is a named bundle of allowed skills, tools, runtime
  parameters, permissions, and eval cases.
- A routine is a typed DAG of skill/tool/memory nodes with persisted state and
  trace output.
- The LLM context is not the database. Skills and routines must use storage
  contracts for durable state.

### Tool and Action Model

- All tools must have typed input/output schemas.
- Every tool execution must produce a trace node:
  `prompt -> skill -> tool -> parameters -> result -> final answer`.
- Sensitive actions require either explicit confirmation or a scoped automation
  created by the user.
- Trust tiers are required:
  read-only, draft-only, confirmation-required, auto-approved, blocked.

### Security and Evaluation Model

- Community skills and imported URLs must be validated before activation.
- Generated or imported code must be checked for dependency risk and excessive
  permissions.
- Evaluation must cover happy path, failure path, adversarial prompt, offline
  mode, permission denial, and redaction.
- Trace logs must redact secrets, memory content, finance/health data, and
  sensitive tool parameters.

### Spec-Driven Product Model

- Brain, Ask Image, Audio Scribe, Prompt Lab, Memory Vault, Routine OS, and
  Agent Skills must expose their user journeys as deterministic use cases.
- Routine packs need a versioned manifest, preview metadata, schedule rules,
  generated tasks, and rollback behavior.
- Memory extraction needs source provenance, editable user confirmation, entity
  links, retention rules, and deletion support.

## Immediate Trackers

- #324: internal SDLC and spec gates
- #325: capability profiles and DAG orchestration
- #326: security and evaluation harness
- #323: per-ticket deterministic use cases and automation flows
- #322: sprint sequencing
