# ADR-0006: Mobile UI Governance and Shell Ownership

## Status

Accepted

## Date

2026-06-27

## Context

Airo's shell currently mixes shared and local UI responsibilities. Root shell
surfaces own global chrome, but feature screens can still render local `AppBar`
instances, hardcode destination behavior, and reference shell imagery directly.
This leads to duplicate headers, inconsistent navigation behavior, and repeated
visual decisions across unrelated features.

The repo also needs a durable governance layer so future UI changes do not
reopen the same shell ownership questions.

## Decision

We establish Mobile UI governance with the following rules:

1. Shared shell code owns global chrome, route-to-header behavior, and primary
   destination metadata.
2. Feature screens own content presentation, but not shell-level header or
   navigation policy.
3. For any route state, exactly one layer owns the visible top header:
   shell-owned, route-owned, or intentionally hidden for immersive flows.
4. Shared token roles, navigation metadata, and shell asset references must be
   centralized before feature-level UI changes are accepted.
5. Global shell header and native/platform header behavior must converge on one
   visible top-chrome surface rather than stacking duplicate bars.
6. Narrow-screen primary navigation must use a constrained action budget, with
   lower-frequency destinations routed through centrally owned overflow or
   hamburger patterns.
7. Governance docs must exist in the repo so follow-up execution issues can
   implement shell/header, token/navigation, and asset work against a stable
   contract.

## Consequences

### Positive

- reduces duplicate header regressions
- gives feature teams a clear shell boundary
- centralizes navigation and shared visual decisions
- protects vertical space on phones
- encourages native-first interaction patterns
- lets implementation work be split into smaller focused issues

### Negative

- adds upfront process for UI work that previously changed screens directly
- may require migration work across legacy screens before consistency improves

### Risks

- governance can drift if follow-up UI work does not update the shared docs
- partial migration may temporarily leave mixed old and new shell behavior
- aggressive consolidation can hide feature actions if overflow behavior is not
  tested carefully

## Alternatives Considered

### Alternative 1: Let each feature own its own header and nav affordances

Rejected because it preserves duplicate app bars, inconsistent shell behavior,
and repeated route-level decisions.

### Alternative 2: Solve only the current duplicate header bug without docs

Rejected because the repo has repeated shell, token, and asset governance gaps,
not just one header bug.

## Related Decisions

- [ADR-0001](0001-package-structure.md) - Modular package ownership boundaries

## References

- [Mobile UI Agent Packet](../agents/mobile-ui-agent/README.md)
- [Mobile UI / UX Standards](../standards/mobile-ui-ux-standards.md)
- [Mobile UI Agent Phase Plan](../agents/mobile-ui-agent/UIUX_PHASE_PLAN_2026-06.md)
- [Issue #397](https://github.com/DevelopersCoffee/airo/issues/397)
