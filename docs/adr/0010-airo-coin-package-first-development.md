# ADR-0010: Airo Coin package-first development

## Status

Accepted

## Date

2026-07-22

## Context

Airo Coin is being built as a focused module first, then embedded into the
Airo super app once the standalone package is correct. The repository still
contained older super-app finance code under `app/lib/features/coins` and a
retired `packages/airomoney` residue, which made it easy for agents to place
new coin work in the wrong home and hard for maintainers to see the focused
Airo Coin implementation.

The current Airo Coin vault implementation already follows the desired split:

- `packages/platform_coin_vault` owns vault storage, encryption, validators,
  repositories, and data contracts.
- `packages/feature_coin` owns the vault user journey, session orchestration,
  record forms, screen security, and clipboard behavior.
- `app/lib` embeds the package through route and dashboard wiring only.

Future Airo Coin pro features, such as encrypted backup and restore, need a
stable open-core contract while the paid implementation remains in the private
`airo-pro` overlay.

## Decision

All new Airo Coin work is package-first:

- reusable non-UI logic goes in `packages/platform_coin_*`;
- feature UI and orchestration go in `packages/feature_coin`;
- native integrations go in coin plugin packages behind package interfaces;
- paid/pro implementations go in the `airo-pro` coin overlay and expose only
  stable public contracts through `core_entitlements` and package interfaces;
- `app/lib` receives only entrypoints, routing, dependency injection, and
  navigation-card wiring.

`packages/airomoney` is retired. The old `app/lib/features/coins` tree is
treated as legacy super-app finance code and a migration source, not a target
for new behavior. New PRs that add Airo Coin business logic there fail review
unless they are explicitly extracting or deleting legacy app-layer code.

The public entitlement contract now reserves
`ProFeature.coinEncryptedBackupRestore` with stable id
`coin_encrypted_backup_restore` for the future `airo-pro` coin overlay.

## Consequences

### Positive

- Maintainers can find active Airo Coin code in the package tree instead of
  hunting through the super-app shell.
- Standalone package validation becomes the default proof before super-app
  embedding.
- Pro coin capabilities get stable IDs without exposing private billing,
  backup, or sync implementation details in the open repository.

### Negative

- The existing `app/lib/features/coins` finance code is not moved by this ADR;
  it remains visible as legacy debt until a separate extraction plan deletes
  or migrates it safely.
- Package-first work may require small app-shell follow-up changes for routes
  and cards, but those changes must stay thin.

### Risks

- Agents may still search for `coins` and edit the legacy app tree. The
  constitution and council policy now make that a review-blocking defect.
- Adding more pro IDs without matching overlay work can create product
  confusion. Future pro IDs need a linked roadmap item and owner review.

## Related Decisions

- ADR-0001: Modular Package Structure
- ADR-0006: Mobile UI Governance and Shell Ownership
- ADR-0009: Airo Coin vault crypto design and threat model

## References

- `docs/PLATFORM_CONSTITUTION.md`
- `docs/agents/AGENT_POLICY.md`
- `docs/agents/COUNCIL.md`
- `packages/feature_coin`
- `packages/platform_coin_vault`
- `packages/core_entitlements`
