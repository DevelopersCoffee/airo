# Airo Agent Policy

Every implementation agent working in this repository must follow the agent
lifecycle in [docs/agents/AGENT_POLICY.md](docs/agents/AGENT_POLICY.md) before
writing feature code.

## Required Before Implementation

For every feature, bug fix, or architecture change:

1. Identify the owning agent and impacted modules.
2. Run the Critical Agent clarity gate.
3. Define the cross-agent contract if more than one module is touched.
4. Add deterministic use cases and automation flows to the GitHub issue.
5. Confirm whether the work belongs in framework code, application code, or both.
6. Only then start implementation.

Framework agents own reusable contracts, runtime boundaries, storage schemas,
security rules, and platform abstractions. Application agents own product
journeys, screens, copy, routine packs, templates, and end-user workflows.
Neither layer should make unilateral changes across the boundary.

If the required policy artifacts are missing, stop implementation and add them
to the issue first.
