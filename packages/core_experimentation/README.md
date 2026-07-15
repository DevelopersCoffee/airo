# Core Experimentation

Vendor-neutral experimentation and remote-config guardrail contracts for Airo.

This package owns stable assignment, rollout eligibility, kill-switch checks,
remote-config safety validation, and public decision serialization. Product and
feature modules should consume evaluated decisions from this package or an
adapter built on it rather than importing a vendor remote-config SDK directly.

## Scope

- Product profile and release channel identifiers used by experimentation.
- Anonymous assignment subject metadata without raw user identifiers.
- Experiment definitions with variants, rollout percentage, module,
  entitlement, profile, release channel, version, and region eligibility.
- Remote-config flag definitions with explicit override guardrails.
- Kill-switch registry that blocks experiments and flags before rollout.
- Deterministic evaluator for experiment assignment and remote-config
  eligibility.
- Public maps that expose stable ids, buckets, and guardrail codes only.

This package does not include Firebase Remote Config, LaunchDarkly, Statsig, or
another provider SDK. It also does not define product UI, dashboards, alerting,
or server-side assignment storage.
