# Airo Platform / Airo TV Site Split — Task List

## Execution Status — 2026-07-22

- [x] Public release evidence reconciled to the published `airo-tv-v0.0.3` release.
- [x] Root platform page, Airo TV product page, and `/tv/guides/` hub implemented.
- [x] Shared responsive/accessibility styling and release-branding audit updated for the split.
- [x] Local audit and browser checks completed at 1920x1080, 1280x720, 1024x576, and 390x844.
- [ ] Publication remains pending explicit maintainer approval; no deployment has been requested or performed.

## Task 1: Establish public claim evidence

**Description:** Create the site-change feature packet and reconcile the
version, release, device, provider, and screenshot evidence that will govern
all public copy.

**Acceptance criteria:**
- [ ] The public state of Airo TV v0.0.3 is resolved against a release asset,
      checksum, release note, feature matrix, and qualification record.
- [ ] Each intended page claim has an evidence source and a claim state.
- [ ] Screenshot/demo rights and external-media decision are recorded.

**Verification:**
- [ ] Product and Release owners approve the evidence ledger.
- [ ] No planned/private capability is marked Available.

**Dependencies:** None

**Files likely touched:** `docs/release/*`, public-site issue/feature packet

**Estimated scope:** Medium

---

## Completed worktree: feature_coin UI Phase 0

- [x] Add typed UI refs, summary aggregation, and screen-security service.
- [x] Add lock gate and grouped home list widgets.
- [x] Add masked detail sheet with reveal/copy.
- [x] Add add/edit forms with validation and duplicate handling.
- [x] Export the UI surface and clean stale key-manager documentation.
- [x] Wire `/money/vault` and run the recorded focused validation.

## Task 2: Approve the public content contract

**Description:** Lock the root-vs-TV information architecture, approved module
names, nav/CTA/redirect map, and shared visual/content primitives before page
work begins.

**Acceptance criteria:**
- [ ] `/`, `/tv/`, and `/tv/guides/` have unambiguous responsibilities.
- [ ] Non-TV modules have approved labels and clear non-shipping states.
- [ ] Airo TV Pro disclosure is approved and contains no private details.

**Verification:**
- [ ] Documentation, Product, UX, and Release owners sign off.
- [ ] Redirect map covers present root anchors and guide URLs.

**Dependencies:** Task 1

**Files likely touched:** `docs/`, feature packet, redirect configuration

**Estimated scope:** Small

## Task 3: Build shared public-site primitives

**Description:** Separate shared navigation, footer, styling, badges, and
accessible visual patterns from the current root page so both pages stay
consistent without duplicating their product content.

**Acceptance criteria:**
- [ ] Shared shell supports root and `/tv/` navigation with correct relative links.
- [ ] Claim-status badges render with text, not color alone.
- [ ] Interaction targets meet 44px and reduced-motion/static fallbacks work.

**Verification:**
- [ ] Local Pages build succeeds.
- [ ] Keyboard navigation and mobile menu pass manual checks.

**Dependencies:** Task 2

**Files likely touched:** `docs/assets/airo-tv/site.css`,
`docs/assets/airo-tv/site.js`, shared HTML includes/partials if adopted

**Estimated scope:** Medium

## Task 4: Rebuild the Airo root page as a platform home

**Description:** Replace the root TV-led experience with the platform narrative,
architecture layers, foundation ledger, module map, community direction,
roadmap, and one concise Airo TV hand-off.

**Acceptance criteria:**
- [ ] Root explains platform → modules → providers without a TV setup flow.
- [ ] Airo TV is the sole active product link and points to `/tv/`.
- [ ] Future module areas visibly say Exploring/Planned and make no delivery promise.

**Verification:**
- [ ] Root contains no live player, product download CTA, or TV device matrix.
- [ ] Platform diagram remains understandable with JavaScript disabled.

**Dependencies:** Tasks 1–3

**Files likely touched:** `docs/index.html`, shared public-site assets

**Estimated scope:** Medium

## Task 5: Create the detailed Airo TV product page

**Description:** Create `/tv/` as the full Airo TV landing page and move the
verified product, release, device, capability, Community Voice, Pro, and trust
content out of the root page.

**Acceptance criteria:**
- [ ] Download and support statements reflect the evidence ledger.
- [ ] Capabilities, devices, and providers carry accurate state/limitations.
- [ ] Airo TV boundary and Pro disclosure are visible and compliant.

**Verification:**
- [ ] No unverified provider/performance/premium claim remains.
- [ ] Any retained live demo requires explicit user action and passes the
      branding policy’s lifecycle/disclosure requirements.

**Dependencies:** Tasks 1–4

**Files likely touched:** `docs/tv/index.html`, shared public-site assets,
authorized release screenshots

**Estimated scope:** Medium

## Task 6: Move TV documentation and preserve links

**Description:** Make `/tv/guides/` the public TV documentation entry point,
add a concise quick start, and preserve every current guide/root route through
permanent redirects or maintained anchor targets.

**Acceptance criteria:**
- [ ] Install, source setup, browse/search, Cast, device support,
      troubleshooting, and FAQ are discoverable from `/tv/guides/`.
- [ ] Old guide links do not lead to a 404.
- [ ] Documentation clearly differentiates available, experimental, and
      unsupported device paths.

**Verification:**
- [ ] Local link crawl has no broken internal links.
- [ ] Manual quick-start task can be completed from the documentation.

**Dependencies:** Task 5

**Files likely touched:** `docs/airo-tv/guides/index.html`, `docs/tv/guides/`,
`docs/_config.yml`, redirect files if needed

**Estimated scope:** Medium

## Task 7: Qualify the public pages

**Description:** Run the public-page audit and responsive/accessibility checks,
record evidence, and request explicit publication approval.

**Acceptance criteria:**
- [ ] Branding audit, local build, and link check pass.
- [ ] Required 1920x1080, 1280x720, 1024x576, and 390x844 captures show no
      overlap or horizontal overflow.
- [ ] Claim changes and withheld private claims are recorded in the feature packet.

**Verification:**
- [ ] `python3 .agents/skills/airo-release-branding/scripts/audit_public_page.py` passes.
- [ ] Keyboard navigation and `prefers-reduced-motion` checks pass.
- [ ] Maintainer explicitly approves deployment.

**Dependencies:** Tasks 4–6

**Files likely touched:** `docs/`, `artifacts/` or approved validation evidence

**Estimated scope:** Small

## Checkpoint: Before implementation

- [ ] Tasks 1 and 2 are approved.
- [ ] Public release state is unambiguous.
- [ ] Owners, public-claim contract, use cases, redirects, and verification
      flows are attached to the implementation issue.

## Checkpoint: Before publication

- [ ] Tasks 3–7 pass their acceptance criteria.
- [ ] All claim states are evidence-backed.
- [ ] Explicit maintainer approval to deploy is recorded.
