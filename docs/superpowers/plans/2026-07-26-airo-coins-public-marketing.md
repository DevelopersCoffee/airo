# Feature Packet: Airo Coins public marketing

## Intake and clarity gate

**Problem:** The public site centers Airo TV and gives the developing Coins
module no clear, truthful place beside it.

**User / outcome:** A visitor can see Airo TV and Airo Coins as focused modules
under Airo, understand their different release states, and enter a dedicated
Coins story without mistaking it for a released currency, wallet, investment,
bank, or financial-advice product.

**Primary owner:** Coins / Finance Agent owns product truth. Chief
Documentation Officer owns public information architecture.

**Reviewers:** Product Manager, Chief UX Officer, Chief QA Officer, Chief
Release/DevOps Officer, and Chief Security Officer.

**Impacted modules:** `docs/index.html`, `docs/coins/index.html`, and the shared
public stylesheet.

**Layer:** Application/public-product communication only. No framework,
runtime, schema, crypto, entitlement, or user-data changes.

**Base:** `codex/coins-marketing` was created at
`2dd0fa57eb2267fe2cdb22c6322e7a7c22dc6741`, the freshly fetched
`origin/main` tip on 2026-07-26.

The connected GitHub integration initially rejected issue creation with HTTP
403 (`Resource not accessible by integration`). The authenticated `gh` CLI was
then used to create
[#1163](https://github.com/DevelopersCoffee/airo/issues/1163). This file remains
the repository copy of the policy artifact.

**Open question / claim gate:** There is no public Coins release artifact. All
product outcomes remain `In development` or `Planned`. Copy must not state
price, timing, balances, transactions, returns, coin/token value, investment,
financial advice, or availability.

**Decision:** Ready with that claim boundary.

## Cross-agent contract

The Coins / Finance Agent provides a claim ledger containing capability,
customer outcome, evidence, state, and limitation. The Documentation owner
turns it into plain-language static copy with visible states and evidence
links. Missing or conflicting evidence downgrades a claim to `Planned` or
omits it. No financial identifiers, key-management details, private commercial
rules, credentials, or real account screenshots may be published. There are no
runtime permissions, persistence changes, APIs, migrations, or application
state changes.

| Claim | State | Evidence | Boundary |
| --- | --- | --- | --- |
| Airo Coins is a focused module | In development | ADR-0010; `feature_coin` | No download |
| Secure personal-record vault direction | In development | ADR-0009; Phase 0 spec | Outcomes only |
| Locked, masked, reveal-on-demand journey | In development | Phase 0 spec | Concept UI only |
| Local-first financial organization | Planned | Coins sharing plan | No advice or money movement |
| Airo TV is available | Available | Existing release evidence | Preserve BYOC boundary |

## Deterministic use cases

### UC-001: Discover the two products

Given the homepage on any supported viewport, a visitor can identify Airo as
the umbrella, Airo TV as available, and Airo Coins as in development. With
JavaScript disabled, both entries and links remain usable. No data is created.

### UC-002: Understand the Coins boundary

On the Coins page, a visitor sees the vault direction, an `In development`
state, and evidence links instead of download or purchase prompts. The page
requests no financial data, wallet connection, signup, or permission.

### UC-003: Avoid product confusion

Airo TV retains its product/release journey. Coins has no download CTA and
does not imply it is bundled into TV. Direct `/tv/` and `/coins/` routes keep
the same hierarchy at narrow widths and under reduced motion.

## Automation flows

### AUTO-001: Product hierarchy

Serve `docs/` and load `/`, `/tv/`, and `/coins/` at 1920x1080, 1280x720,
1024x576, and 390x844. Assert visible states, working navigation, 44px targets,
no horizontal overflow, and no overlap. Repeat the key journey with JavaScript
disabled and reduced motion.

### AUTO-002: Claim boundary

Run the branding audit and focused content searches. Assert no copy calls
Coins available, offers a coin/token sale, promises value or returns, states
pricing/timing, or gives financial advice. Every capability must map to the
claim ledger.

## Implementation boundaries and rollback

- Framework and application runtime files: none.
- Public files: homepage product choice, Coins landing page, shared CSS.
- Verification: host-only static server and browser viewports.
- Out of scope: schemas, transactions, balances, sync, token issuance,
  purchases, pricing, advice, release, deployment, or publication.
- Rollback: revert the static files; no user data or migration is involved.

## Local implementation evidence

- Worktree: `/Users/udaychauhan/workspace/airo-worktrees/coins-marketing`
- Branch: `codex/coins-marketing`, created from fetched `origin/main`
- Implementation commit:
  `99bfcc0f705beb65c4ab009b16b09c743f9317dc`
- Release-branding audit: passed
- `git diff --check`: passed
- Browser viewports: 1920x1080, 1280x720, 1024x576, and 390x844
- Runtime checks: no console errors, no horizontal overflow, 44px visible
  controls, keyboard-operable mobile menu, reduced-motion rendering, and
  no-JavaScript product navigation
- Publication: not performed; explicit maintainer deployment approval remains
  required
