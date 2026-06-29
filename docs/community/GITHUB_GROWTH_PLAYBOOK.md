# GitHub Growth Playbook

This playbook turns "get more stars and forks" into developer-success work. The
goal is not vanity metrics or fake engagement. The goal is to make Airo easy to
understand, useful to run, and safe to contribute to.

## Positioning

Airo is for developers interested in:

- Local-first AI apps.
- Flutter super-app architecture.
- On-device model routing and fallback.
- Agent skills, routine packs, and automation flows.
- Privacy-aware mobile UX.

The public message should stay concrete: show what works, what is planned, and
where contributors can help. Do not claim adoption numbers, production maturity,
or license terms that the repository does not prove.

## Growth Loop

1. **Listen**
   - Review new GitHub issues weekly.
   - Track setup failures, unclear docs, and repeated questions.
   - Watch Flutter, on-device AI, and local-first developer communities for real
     problems Airo can help explain or solve.

2. **Improve DX**
   - Fix the top setup or contribution blockers before publishing more content.
   - Keep README commands current.
   - Maintain good first issues with clear reproduction or acceptance criteria.

3. **Create Proof**
   - Publish small demos, screenshots, recordings, and docs that show actual app
     behavior.
   - Prefer "how we built/fixed X" over generic launch posts.
   - Include exact commands and failure modes.

4. **Invite Contribution**
   - Link to a specific issue, not just the repository homepage.
   - Explain the skill level, expected files, and verification command.
   - Thank contributors by referencing their concrete fix or reproduction.

5. **Feed Back**
   - Turn repeated community questions into docs, tests, or issues.
   - Close the loop publicly when a contributor-reported issue ships.

## Weekly Maintainer Routine

Run this once per week:

```text
1. Triage new issues and PRs.
2. Label at least three small, real tasks as good first issue or help wanted.
3. Check README and CONTRIBUTING commands against the Makefile.
4. Add one screenshot, demo note, or troubleshooting fix from recent work.
5. Post one authentic update that links to a specific contribution opportunity.
```

## Contribution Funnel

| Funnel stage | Developer question | Repo surface |
| --- | --- | --- |
| Discover | What is Airo and why should I care? | README first screen |
| Evaluate | Can I run it and understand the stack? | Quick Start, Repository Map |
| Choose | What can I help with today? | Good first issues, CONTRIBUTING |
| Implement | What checks and policy apply? | Agent Policy, PR template |
| Return | Did my work matter? | Issue closure notes, release notes, attribution |

## Open-Source Content Ideas

- "Building a local-first AI app shell in Flutter."
- "How Airo routes between local and remote model capabilities."
- "Designing deterministic automation flows for agent-built features."
- "What broke when we tried to make mobile AI features work offline."
- "A contributor's guide to Airo's package boundaries."

Every post should link to a runnable command, a real issue, or a merged PR.

## Metrics To Track

Track these manually until automation exists:

- Stars and forks by week.
- New contributors by month.
- First-response time for issues and PRs.
- PRs merged from external contributors.
- Good-first-issue completion rate.
- Setup/documentation issues opened by new contributors.
- README to clone/fork conversion signals where GitHub exposes them.

Metrics are for deciding what to improve, not for pressuring contributors.

## Guardrails

- Do not astroturf or ask people for fake engagement.
- Do not buy stars.
- Do not spam communities.
- Do not overstate maturity, privacy guarantees, benchmarks, or roadmap dates.
- Do not accept major external code until the root license is confirmed.
- Do not send contributors into vague issues without acceptance criteria.

## Immediate Backlog

- Confirm and add the root repository license.
- Add screenshots or a short demo GIF to the README.
- Create a curated `good first issue` list with 5-10 small tasks.
- Add a docs link checker for local Markdown links.
- Enable GitHub private vulnerability reporting if it is not already enabled.
