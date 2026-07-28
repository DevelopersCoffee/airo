# Context engineering standard

How Airo writes files that agents load automatically — `AGENTS.md`, `CLAUDE.md`,
`.claude/agents/*.md`, and the skills under `.agents/skills/` and
`.claude/skills/`. Adopted from Anthropic's
[new rules of context engineering for Claude 5 generation models](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models)
(2026-07-24), where removing over 80 % of the Claude Code system prompt cost
nothing on coding evals.

Read this before editing any of those files.

## What changed

| Old habit | Now |
|---|---|
| Give the agent rules for every worst case | Let it use judgement; keep rules for things it genuinely cannot infer |
| Show examples of how to call each tool | Design the interface so its shape carries the intent |
| Put everything up front in one file | Progressive disclosure — a tree of files loaded when relevant |
| Repeat important instructions | Say it once, in the place that owns it |
| Hoard memory in `CLAUDE.md` | Reference docs, specs, code, and tests carry the detail |
| Specs as prose | Prefer high-fidelity references: code, tests, HTML mockups |

## Rules for this repo

1. **`AGENTS.md` is the only always-loaded file, and stays under ~70 lines.**
   `CLAUDE.md`, `GEMINI.md`, and `.augment/rules.md` are symlinks to it, so
   Claude Code, Codex, Gemini, Antigravity, and Augment all read one text. A new
   agent tool gets a new symlink, never a new file — a per-tool rules file
   drifts, and then each agent is working from different instructions. If a
   change pushes `AGENTS.md` past the cap, something belongs in `docs/` or a
   skill instead.
2. **Spend the budget on gotchas.** Non-obvious constraints that cost an agent a
   wasted cycle — the isolate boundary, per-flavor pubspecs, the pro bootstrap
   no-op. Anything discoverable by listing the repo or reading a pubspec does not
   go in.
3. **Point, do not restate.** `AGENTS.md` links to `AGENT_POLICY.md`,
   `COUNCIL.md`, and `WORKFLOW.md`; the linked file owns the detail. A rule
   written in two places will drift, and the agent then has to reconcile them.
   `.claude/agents/*.md` follow the same shape: role, ownership, and a pointer to
   the live criteria in `COUNCIL.md`.
4. **No mandatory routing tables.** Do not enumerate which skill to invoke for
   which work type. Skill descriptions already carry their own triggers, and a
   hardcoded table goes stale and conflicts with the agent's own judgement.
5. **One instruction, one owner.** Before adding a rule, grep for it. Duplicated
   or near-duplicated policy is the failure mode this standard exists to prevent.
6. **Long skills split.** A `SKILL.md` over roughly 150 lines moves its detail
   into `reference/` files the skill loads on demand — see
   `.claude/skills/android-tv-design/`.
7. **Generic skills are not vendored.** The `addyosmani/agent-skills` pack
   installs globally via `scripts/skills.sh` and is gitignored. Only
   Airo-specific skills are committed.

## When you disagree

These are defaults, not a gate. If a change genuinely needs an explicit rule,
add it and say why in the PR. The failure this standard guards against is
accumulation without review, not any single rule.
