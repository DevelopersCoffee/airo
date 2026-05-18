# ADR-0005: Adopt UCP-Compatible Commerce Adapter

## Status

Proposed

## Date

2026-05-19

## Context

Airo is expanding toward agent-driven commerce and restaurant ordering. Universal Commerce Protocol (UCP) is emerging as an open standard for agentic commerce, with public specifications for business discovery, capability negotiation, checkout, fulfillment, payment handlers, and order lifecycle events.

The project should be ready for AI agents to browse menus, build carts, resolve prices, and place orders. At the same time, UCP is still evolving and external platform distribution is not guaranteed by simply implementing the protocol.

We need an adoption path that gives Airo clean commerce architecture now without coupling the core domain to one external protocol version.

## Decision

Adopt UCP-compatible commerce primitives and expose UCP through an adapter layer.

The internal commerce domain will own canonical models and commands for menu projection, checkout sessions, fulfillment, discounts, payment instruments, and order lifecycle. UCP request/response payloads will terminate at a boundary adapter that translates between external protocol schemas and internal domain commands.

Initial public exposure will be feature-flagged. The first implementation will prioritize internal UCP compatibility, staging profile generation at `/.well-known/ucp`, deterministic checkout commands, idempotency, and mock payment handling. Production UCP endpoints and real payment handlers will be added after merchant onboarding, request signing, payment integration, and conformance checks are in place.

## Consequences

### Positive

- Airo gains an agent-ready commerce model without waiting for a specific partner rollout.
- UCP spec changes are isolated to adapter mapping code instead of leaking across the domain.
- The same internal commerce commands can support in-app ordering, UCP, ACP, MCP tools, and staff workflows.
- Payment risk is reduced by requiring tokenized payment handler abstractions instead of raw credential handling.
- Merchant business rules remain server-authoritative.

### Negative

- The adapter adds an extra layer to design, test, and maintain.
- Full partner compatibility still requires platform-specific onboarding and conformance work.
- UCP-shaped models may add concepts that are not needed for the simplest in-app restaurant ordering flow.

### Risks

- UCP may change materially before broad production adoption.
- Implementing the profile without operational readiness could expose incomplete or misleading capabilities.
- Payment handler integration can expand compliance scope if raw credentials accidentally enter Airo systems.
- Complex restaurant modifiers may not map cleanly to generic commerce schemas without careful validation.

## Alternatives Considered

### Build Native Ordering APIs Only

Implement restaurant ordering with internal APIs and ignore UCP until a platform requires it.

Rejected because it risks creating models that are hard to expose to agents later, especially around checkout sessions, payment handler negotiation, idempotency, and lifecycle events.

### Implement Full UCP First

Expose the complete public UCP surface before building merchant-specific ordering workflows.

Rejected because public protocol exposure requires request signing, payment handler readiness, conformance testing, operational dashboards, and partner access. That is too much scope for the first step.

### Adopt ACP Instead of UCP

Prioritize OpenAI/Stripe Agentic Commerce Protocol because it maps to ChatGPT-style checkout.

Rejected as the primary architecture because ACP is narrower around agent checkout/payment flows. ACP can be added later as another adapter over the same commerce domain.

### Use MCP Tools Only

Expose menu and ordering actions as MCP tools for AI agents.

Rejected as the primary commerce protocol because MCP is a tool/context transport, not a full commerce protocol. MCP may still be useful as an additional transport.

## Related Decisions

- [ADR-0001](0001-package-structure.md) - Modular Package Structure
- [UCP Agentic Commerce Requirements and Design](../features/commerce/UCP_AGENTIC_COMMERCE_REQUIREMENTS_AND_DESIGN.md)

## References

- [Universal Commerce Protocol](https://ucp.dev/)
- [UCP GitHub Repository](https://github.com/Universal-Commerce-Protocol/ucp)
- [Google UCP Guide](https://developers.google.com/merchant/ucp)
- [Google: Under the Hood: Universal Commerce Protocol](https://developers.googleblog.com/under-the-hood-universal-commerce-protocol-ucp/)
- [Shopify Engineering: Building the Universal Commerce Protocol](https://shopify.engineering/UCP)
- [Agentic Commerce Protocol](https://www.agenticcommerce.dev/)
