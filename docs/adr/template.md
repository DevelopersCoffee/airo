# ADR-NNNN: Title

## Status

Proposed | Accepted | Deprecated | Superseded by [ADR-XXXX](XXXX-title.md)

## Date

YYYY-MM-DD

## Context

What is the issue that we're seeing that is motivating this decision or change?

Describe the context and problem statement.

## Decision

What is the change that we're proposing and/or doing?

## Contract Impact

**Required. Fill every row — "none" is an answer, blank is not.**

An architecture change that does not say what it invalidates leaves the old
tests, budgets, and approvals standing. They then keep passing against a
contract that no longer exists, which is silent rather than loud, and is how a
conformance suite becomes decorative.

| Question | Answer |
|---|---|
| Which runtime contracts change? | |
| Which conformance tests become invalid? | |
| Which benchmarks must be re-run? | |
| Which review roles must re-review? | |
| Is G0 required again? | Yes / No |

Notes on filling it:

- **Contracts** — name them and say whether the version changes. A contract
  version change is a runtime major version.
- **Conformance tests** — a test is invalid when the property it protects moved,
  *including when it still passes*. That case is the reason this row exists.
- **Benchmarks** — a budget measured against the old shape is not evidence about
  the new one. List it even if you expect it to improve.
- **Review roles** — per the Decision Matrix in `docs/agents/COUNCIL.md`. Anyone
  who approved the surface being changed re-reviews; a prior approval covers the
  thing that was approved, not its replacement.
- **G0** — yes for anything touching a plan's code blocks or a crate's public
  surface.

## Consequences

### Positive

- List the positive outcomes

### Negative

- List the negative outcomes or trade-offs

### Risks

- List any risks associated with this decision

## Alternatives Considered

### Alternative 1: [Name]

Description of alternative and why it was not chosen.

### Alternative 2: [Name]

Description of alternative and why it was not chosen.

## Related Decisions

- [ADR-XXXX](XXXX-title.md) - Related decision

## References

- [Link to relevant documentation]()
- [Link to relevant discussion]()

