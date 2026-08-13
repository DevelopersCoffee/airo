# Coins AI UX surfaces — COINS-AI-10 design

Date: 2026-08-13
Status: Draft — awaiting chief-ux-officer + product-manager review (issue
#1653's own acceptance criterion #1: no implementation before this passes)
Related: milestone 27 epic #1643, #1645 (NL split), #1646 (receipt LLM
layer), #1647 (NL search), #1648 (auto-categorization, merged #1660), #1649
(recurrence/anomaly detection, merged #1659), #1650 (eval harness, PR #1685),
#1651 (privacy positioning), #1652 (entitlement gating)

## Why this doc exists

#1645–#1649 each define an extraction or detection capability and assume a
UI surface exists to host it. None does yet, beyond one regex-only seed (see
below). Building five feature-specific screens independently would mean five
different guardrail patterns, five different "the model got it wrong"
recovery flows, and five chances to get the trust story wrong. This doc
designs the shared surfaces once, so #1645–#1649 land into ready UI instead
of each inventing its own.

## What already exists (the seed to evolve, not replace)

`CoinsDashboardScreen`'s `_QuickAddExpenseCard`
(`app/lib/features/coins/presentation/screens/coins_dashboard_screen.dart:529`)
is already a miniature version of the pattern this doc formalizes: a text
field ("Pizza 420 split with Alex"), a `QuickAddExpenseParser` (regex-only,
COINS-AI-5's baseline) turns it into a `QuickExpenseDraft`, and the app
navigates to `AddExpenseScreen` pre-filled with that draft for the user to
edit and explicitly save. Nothing commits from the quick-add card itself.

This is proof the shape works product-wise. It is not yet: reachable from
more than one screen, routed by extracted *intent* rather than always
assuming "add an expense," backed by anything smarter than keyword regex, or
a reusable component another feature could adopt. This doc's job is to
generalize it, not to invent a new pattern next to it.

## Scope

**In:** the shared surfaces every COINS-AI feature renders through —
unified NL entry point, draft-confirm card, receipt itemization review
affordance, digest card, trust cues, non-happy states. Phone + tablet only
(no TV surface for Coins AI v1, matching Coins' existing scope).

**Out:** the feature-specific extraction logic behind each surface
(#1644–#1649's own work), the entitlement/tier gate itself (#1652 — this doc
assumes it exists and specifies how surfaces *respond* to it), and any
screen implementation. Per the issue: screens ship in the **pro** package;
this doc, and the shared draft-confirm component if approved, are the
candidate for public `core_ui`-style placement — a separate call for
whoever reviews this against `docs/agents/COUNCIL.md`'s module-ownership
rules, not decided here.

## Surface 1 — Unified "Ask Coins" entry point

One field, reachable from two places: the Coins dashboard (replacing/
absorbing `_QuickAddExpenseCard`'s spot) and the top of the splits screen.
Same widget in both locations — not a dashboard-only feature that splits
duplicates separately.

**Routing by intent:** on submit, the utterance goes through #1644's
extraction seam. Three outcomes:
- Split/expense intent → draft-confirm card (Surface 2), pre-filled, exactly
  today's flow but AI-extracted instead of regex-extracted.
- Search intent (#1647) → inline result list under the field, not a screen
  navigation — asking "how much did I spend on food last month" should not
  feel like leaving the app.
- Unrecognized → a "can't answer that" state with 2-3 suggestion chips
  ("Add an expense", "Search transactions", "Split a bill") rather than a
  bare error. The existing quick-add card's fallback SnackBar
  ("Try an amount like...") is the low-tier version of this same idea —
  reuse its tone, not a generic "sorry" message.

**Low-tier / model-unavailable path:** when #1652's gate says AI is
unavailable (no model, entitlement absent, device tier too low), the field
stays present and still works — it falls back to today's regex parser for
expense/split intent, and search/digest features that need real extraction
simply don't route (their entry points are hidden per this issue's
acceptance criterion, not shown-then-broken).

## Surface 2 — Draft-confirm card (the shared guardrail)

The single component every LLM-touched mutation renders through: split
draft, expense draft, category correction, itemized receipt line edits.
Structurally identical to what `AddExpenseScreen` already does for the
regex quick-add path — the design contribution here is naming it, making it
reusable, and adding what regex extraction never needed:

- **Explicit confirm, no auto-commit.** Already true of `AddExpenseScreen`
  today; the shared component keeps it true by construction, not by each
  feature remembering to add a confirm button.
- **Every field independently editable**, not just the header/total — a
  wrong single line item must be fixable without discarding the whole
  draft.
- **Provenance badge**: "auto-read" or "AI-drafted" on any field whose value
  came from extraction rather than direct user input, distinguishable from
  fields the user typed themselves. This is what makes the receipt
  itemization surface's "auto-read — check items" badge (below) a special
  case of a general rule, not a one-off.
- **Reject/redo**, not just accept: discard the draft, or edit the original
  utterance/receipt and re-extract, without navigating away and back.

## Surface 3 — Receipt itemization review

Per-item assignment already exists (#257, production-hardening in review).
This surface adds exactly one thing on top: when an item's category or
amount came from #1646's LLM structuring layer (rather than the OCR
pipeline's own deterministic parse), it renders through Surface 2's
provenance badge — "auto-read — check items" is this issue's own suggested
copy, kept as the default. No new screen; #257's itemized split UI hosts
the badge once #1646 exists.

## Surface 4 — Digest card

Weekly/monthly summary, per #1649. A card (dashboard placement, mirroring
`_FinancialSnapshotSection`'s spot) plus a local notification. Copy is
descriptive only — "your Netflix went up ₹100" — never prescriptive
("consider cancelling"), matching #1649's own acceptance criterion and
#1651's liability guardrail. Disclaimer ("Based on your on-device
transaction history — not financial advice") sits in the card's footer, not
buried in a settings page, since the milestone gate requires it visible at
the point of the claim, not just documented somewhere.

Non-happy states: no digest yet (new user, insufficient history) shows a
plain "Not enough history yet" card, not an empty digest or a spinner that
never resolves.

## Trust cues

Every AI-touched surface carries the same two signals, consistent with
#1651's "the AI never sees your money leave your phone" positioning:

- **On-device badge**: small, persistent, same visual language across all
  four surfaces above — not a per-feature choice.
- **Honest loading state**: local inference on a 1-4B model takes seconds
  on mid-tier hardware, not milliseconds. The loading state names this
  ("Reading locally... a few seconds") rather than a generic spinner that
  reads as broken when it doesn't resolve instantly. No bare spinner
  anywhere in this doc's surfaces, per the issue's own requirement.

## Responsive behavior

Phone: single-column, entry point full-width, draft-confirm card as a
bottom sheet or full-screen push (implementation detail for whoever builds
Surface 2 — both keep the "no auto-commit" property, this doc doesn't
mandate one over the other).
Tablet: entry point can sit in a persistent side panel per
`docs/ui/RESPONSIVE_STANDARDS.md`; draft-confirm renders as a side panel
rather than a full-screen push, consistent with Mind's Context Workspace
pattern (`docs/superpowers/specs/2026-08-02-airo-mind-device-system-design.md`)
for the same reason — a draft shouldn't cost the user their place in a
wider screen. No TV surface, per scope.

## Entitlement/tier gating (#1652)

Every entry point in this doc is **hidden**, not disabled-with-explanation,
when #1652's gate says unavailable — matching this issue's acceptance
criterion directly. The existing regex quick-add path is the exception: it
is Coins' baseline behavior, not an AI feature, and stays visible
regardless of AI entitlement/tier. This is the one place this doc
distinguishes "AI-gated" from "always available."

## Open questions for review

1. Should the draft-confirm card live in `core_ui` (public, reusable by
   other AI-touched features outside Coins) or stay Coins-pro-scoped? This
   doc's position is "public component, pro-scoped feature wiring around
   it" — the same split #1652 already draws elsewhere — but that's a
   module-ownership call for chief-architect/chief-ux-officer, not settled
   here.
2. Bottom sheet vs. full-screen push for the draft-confirm card on phone —
   flagged above as an implementation choice; reviewers may want to settle
   it now instead.
3. Exact suggestion-chip copy for the "can't answer" state — placeholder
   text above, not final copy; chief-documentation-officer's usual copy
   pass applies once this doc is approved.

## Council

chief-ux-officer + product-manager (required, issue's acceptance criterion
#1) · chief-architect (open question 1, module ownership) · chief-security-
officer (trust cues accuracy, per #1651's positioning claims) ·
chief-documentation-officer (copy pass, once approved)
