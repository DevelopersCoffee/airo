# Airo agent documentation

Five docs, one owner each. `AGENTS.md` at the repo root is the only file loaded
automatically; everything here is read when the work calls for it.

| Doc | Owns |
|---|---|
| [AGENT_POLICY.md](./AGENT_POLICY.md) | Ownership, lifecycle gates, Critical Agent, cross-agent contracts, Feature Packet |
| [COUNCIL.md](./COUNCIL.md) | Domain roster, decision matrix, `module.yaml` schema — tool-agnostic |
| [WORKFLOW.md](./WORKFLOW.md) | Branches, commits, validation, device choice, CI spend, PRs, issue close-out |
| [CONTEXT_ENGINEERING.md](./CONTEXT_ENGINEERING.md) | How to write `AGENTS.md`, agent defs, and skills — read before editing them |
| [KAGGLE_VIBE_CODING_ADOPTION.md](./KAGGLE_VIBE_CODING_ADOPTION.md) | Rationale for the spec-driven, skills, tools, security, and evaluation model |
| [mobile-ui-agent/](./mobile-ui-agent/README.md) | Shell ownership, header governance, UI standards |

Queue state lives on the
[project board](https://github.com/orgs/DevelopersCoffee/projects/2), not in a
coordination issue. Historical bootstrap issues (`#7`, `#11`, `#12`, `#13`,
`#16`) are not a map of current work.

## Starting a task

1. Complete the gates in [AGENT_POLICY.md](./AGENT_POLICY.md).
2. Confirm your reviewers in [COUNCIL.md](./COUNCIL.md).
3. Branch and validate per [WORKFLOW.md](./WORKFLOW.md).

`RULES.md`, `SDLC.md`, and `SEQUENCE.md` were retired on 2026-07-28 — their live
content moved into WORKFLOW.md, and their week-by-week phase plans described a
2026 bootstrap that no longer matches how work is routed. `git log` has them.

## Changing these docs

Open a PR against `docs/agents/*.md`. Read
[CONTEXT_ENGINEERING.md](./CONTEXT_ENGINEERING.md) first — the rule that matters
most is one instruction, one owner. Before adding a rule, grep for it.
