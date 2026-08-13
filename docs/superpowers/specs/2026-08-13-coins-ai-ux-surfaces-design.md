# Coins AI UX surfaces — COINS-AI-10 design

Date: 2026-08-13
Status: **Approved with changes** — chief-ux-officer, product-manager, and
chief-architect reviewed; this revision incorporates every required change.
Issue #1653's acceptance criterion #1 (design doc reviewed before
implementation) is satisfied as of this revision.
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
screen implementation. Per the issue: screens ship in the **pro** package.
The draft-confirm card is the one exception — chief-architect's review
ruled it ships in `core_ui` (public), since it carries zero Coins-specific
business logic (see Surface 2's "Component API" below) and `core_ui`'s
`module.yaml` already forbids the dependencies that would let it leak
domain types. Coins-specific screens adapt their draft models onto its
generic API from the pro package.

## Surface 1 — Unified "Ask Coins" entry point

One field, reachable from two places: the Coins dashboard (replacing/
absorbing `_QuickAddExpenseCard`'s spot) and the top of the splits screen.
Same widget in both locations — not a dashboard-only feature that splits
duplicates separately.

**Bill-split gets explicit prominence, not just intent routing.**
Product-manager review flagged that a generic "ask anything" field risks
burying #1645 — the epic's own #1-ranked differentiator ("highest
differentiation, Splitwise-class apps have nothing here") — as one intent
indistinguishable from search. Resolution: the field's placeholder text and
first-run hint default to a split example ("Pizza 420 split with Alex" —
the existing quick-add placeholder, kept), not a neutral "Ask Coins
anything" prompt. The unified field still routes by intent underneath, but
what a user sees before typing anything signals "split a bill" first.

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
expense/split intent. Search/digest features that need real extraction are
discoverable-but-locked rather than hidden (see Entitlement/tier gating,
below — revised from this doc's original "hidden" draft per
product-manager review), not shown-then-broken.

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

### Component API (core_ui, generic — chief-architect review)

The widget operates on a generic `List<DraftField>` model it owns, never
on `QuickExpenseDraft`/`SplitDraft`/any Coins type. Feature packages map
their domain drafts onto this shape:

- `DraftField`: a label, a value (rendered as the caller supplies — text,
  amount, chip list), a `DraftFieldProvenance` (`userEntered` |
  `aiExtracted`), and an `onEdit` callback. The provenance badge renders
  from the enum, not a Coins-specific "auto-read" string baked into the
  widget.
- Confirm/reject/redo are generic `VoidCallback`/`ValueChanged` parameters
  the caller wires to its own persistence and re-extraction logic. The
  widget commits nothing itself — it only calls back.
- **Loading state takes a required `String message` parameter, not
  optional.** This is the change chief-ux-officer's review required: "no
  bare spinner anywhere" is only true if the API makes a spinner without
  copy impossible to construct, not just a convention every call site is
  supposed to remember.

### Accessibility (chief-ux-officer review — was missing, now required)

- Provenance badge is never color/icon-only: it carries a text label (e.g.
  "AI-drafted") in its semantics, so a screen reader announces it, not just
  a visual dot.
- The loading state's required message is exposed as a live-region
  announcement, so a screen-reader user gets "Reading locally, a few
  seconds" instead of silent time passing.
- Suggestion chips (Surface 1's "can't answer" state) follow standard
  reading-order focus — first chip focusable immediately after the input
  field, not appended to the end of the screen's focus order.

## Surface 3 — Receipt itemization review

Per-item assignment already exists (#257, production-hardening in review).
This surface adds exactly one thing on top: when an item's category or
amount came from #1646's LLM structuring layer (rather than the OCR
pipeline's own deterministic parse), it renders through Surface 2's
provenance badge — "auto-read — check items" is this issue's own suggested
copy, kept as the default. No new screen; #257's itemized split UI hosts
the badge once #1646 exists.

**In scope, flagged by chief-ux-officer review:** `add_expense_screen.dart`
has two existing bare `CircularProgressIndicator()` calls with no
accompanying text (receipt-scan/loading states, lines 342 and 700 as of
this doc's writing). Since Surface 3 reuses this screen and this doc bans
bare spinners everywhere it touches, fixing these two is in scope for
whoever implements Surface 3 — not a pre-existing exception this doc
quietly ignores.

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

**Product-manager note, for the copy pass, not a design change:** pure
description ("your Netflix went up ₹100") is a real tension against
competitors' prescriptive nudges — it's weaker as a marketing hook. The
guardrail stands (#1649's AC and #1651's liability positioning both
require it); the lever available without crossing into prescriptive
language is tone and urgency framing within descriptive copy. Recorded
here so chief-documentation-officer's copy pass doesn't lose this, not
resolved in this doc.

## Trust cues

Every AI-touched surface carries the same two signals, consistent with
#1651's "the AI never sees your money leave your phone" positioning:

- **On-device badge**: small, persistent, same visual language across all
  four surfaces above — not a per-feature choice.
- **Honest loading state**: local inference on a 1-4B model takes seconds
  on mid-tier hardware, not milliseconds. The loading state names this
  ("Reading locally... a few seconds") rather than a generic spinner that
  reads as broken when it doesn't resolve instantly. Enforced structurally,
  not just by convention: Surface 2's `DraftConfirmCard` requires a
  `message` string for its loading state (see Component API) — no bare
  spinner is constructible through it.

**Chief-security-officer review, required addition:** the on-device badge
and this trust-cue claim are verified true today for COINS-AI-5/6's
categorization and detection logic (`feature_coins_core`'s only dependency
is `equatable` — no network client is even reachable), but not yet for the
embedding computation itself: `MerchantEmbedder` is currently a bare
interface with no wired implementation. The badge must be gated on #1651's
automated egress test passing for whatever real extraction path ships
behind it — this doc specs the badge's UI contract now (correctly
sequenced against #1644 being gated), but whoever wires it to a real
model must not treat the badge as already-validated positioning.

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

**Revised from the original draft's "hidden" default, per product-manager
review.** Hiding every AI entry point entirely when #1652's gate says
unavailable removes all upsell surface — a free user never learns the
capability exists. That undersells an epic whose thesis is Pro
differentiation.

Resolution: AI entry points are **discoverable-but-locked**, not hidden —
visible with a small Pro badge, tapping through to an upsell/entitlement
explanation rather than performing the action. This still satisfies the
issue's underlying intent ("low-tier/manual paths reachable from every AI
surface" — the manual/regex path stays the default action on tap) while
giving Pro something to sell against. The one exception, unchanged from the
original draft: the existing regex quick-add path itself is Coins'
baseline behavior, not an AI feature, and needs no Pro badge — it already
works today, gated or not.

This is a change to the issue's literal acceptance-criterion wording
("hidden when entitlement/tier gate says unavailable") — flagging
explicitly rather than silently reinterpreting it, so whoever closes #1653
confirms this reading is what "unavailable" was meant to cover (no
entry-point *action* available without Pro) versus the stricter reading
(no entry-point *visible* at all). Product-manager review's position is the
former; if #1652's owner disagrees, this section needs another pass before
Surface 1 implementation starts.

## Decisions from review (were open questions; now resolved)

1. **Draft-confirm card placement — public, `core_ui`.** Chief-architect
   ruled: the card carries zero Coins-specific business logic (generic
   `DraftField`/provenance enum/callbacks, see Component API above), and
   `core_ui`'s `module.yaml` already forbids the dependencies (`app`,
   domain/data packages) that would let it leak Coins types even by
   accident. Precedent: `airo_channel_card.dart`, `media_card.dart`,
   `empty_state_widget.dart` are all `core_ui` widgets designed against one
   feature first and generalized the same way. Not routed through the
   `airo_pro_bootstrap` seam — that mechanism swaps business-logic
   implementations, and this widget has no implementation to hide.
2. **Bottom sheet vs. full-screen push on phone — left open, by design.**
   Chief-ux-officer confirmed both preserve the no-auto-commit property
   equally; this is an implementation choice for whoever builds Surface 2,
   not a product/UX call that needed settling here.
3. **Suggestion-chip copy — still placeholder, unchanged.** Chief-ux-officer
   confirmed the "can't answer" state's *design* (chips over generic error)
   is right; exact copy is chief-documentation-officer's pass, to happen
   after this doc, as originally planned.

## Council

chief-ux-officer (reviewed, APPROVE WITH CHANGES — accessibility subsection,
required loading-message API, bare-spinner scope, all incorporated above) ·
product-manager (reviewed, APPROVE WITH CHANGES — bill-split prominence and
discoverable-but-locked entitlement gating, both incorporated above) ·
chief-architect (reviewed, ruled `core_ui` placement, incorporated above) ·
chief-security-officer (reviewed, APPROVE WITH CHANGES — egress-gate
requirement on the trust-cue badge, incorporated above) ·
chief-documentation-officer (copy pass — still required, after this doc,
as planned)
