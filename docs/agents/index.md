# 🤖 Airo Agent Documentation

> Multi-Agent Development System for Airo Super App

## 🔗 Quick Links

| Resource | Description |
|----------|-------------|
| [📋 Project Board](https://github.com/orgs/DevelopersCoffee/projects/2) | Live task tracking |
| [📜 Rules](./RULES.md) | Agent operating rules |
| [🧭 Agent Policy](./AGENT_POLICY.md) | Ownership, lifecycle gates, contracts, and Critical Agent workflow |
| [🏛️ Engineering Council](./COUNCIL.md) | Domain roster, decision matrix, `module.yaml` schema — tool-agnostic |
| [🧪 Kaggle Adoption](./KAGGLE_VIBE_CODING_ADOPTION.md) | Spec-driven, skills, tools, security, and evaluation adoption plan |
| [📱 Mobile UI Agent](./mobile-ui-agent/README.md) | Canonical UI/UX owner for shell ownership, header governance, standards, and execution tasks |
| [🔄 SDLC](./SDLC.md) | Development workflow |
| [📅 Sequence](./SEQUENCE.md) | Agent activation order |

---

## 📊 Current Planning Model

Agent ownership and activation no longer depend on one long-lived coordination
issue. Current work is routed through:

- the GitHub Project Board for queue state and sequencing
- [AGENT_POLICY.md](./AGENT_POLICY.md) for ownership, readiness gates, and
  cross-agent contracts
- [RULES.md](./RULES.md) and [SEQUENCE.md](./SEQUENCE.md) for operating
  constraints and rough activation order

Historical bootstrap issues such as `#7`, `#11`, `#12`, `#13`, and `#16` were
useful during the initial repo setup, but they are no longer the canonical map
of current agent work.

---

## 🚀 Getting Started

### For New Agents

1. **Read the Rules:** [RULES.md](./RULES.md)
2. **Complete the Agent Policy gates:** [AGENT_POLICY.md](./AGENT_POLICY.md)
3. **Understand the Process:** [SDLC.md](./SDLC.md)
4. **Check the Sequence:** [SEQUENCE.md](./SEQUENCE.md)
5. **Find your Issue:** Use the GitHub Project Board and current issue queue
6. **Start Working:** Follow the SDLC workflow

### For Project Maintainers

1. **Review Project Board:** https://github.com/orgs/DevelopersCoffee/projects/2
2. **Check readiness gates:** [AGENT_POLICY.md](./AGENT_POLICY.md)
3. **Assign Agents:** Move issues to "Ready" when dependencies met
4. **Track status in GitHub issues/PRs and the board**, not in a separate
   coordination tracker

---

## 📈 Metrics

Track these on the Project Board:

- **Velocity:** Issues closed per week
- **Cycle Time:** Time from Ready to Done
- **Blockers:** Issues in Blocked column
- **Coverage:** Test coverage trend

---

## 📝 Contributing to Rules

1. Identify improvement needed
2. Create PR modifying `docs/agents/*.md`
3. Get approval from maintainer
4. Merge and announce change
