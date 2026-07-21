# Implementation Plan: Separate Airo Platform and Airo TV Public Sites

## Outcome

Make the root GitHub Pages experience (`/airo/`) a calm, credible explanation of
the Airo platform and its modular ecosystem. Move the full customer-facing Airo
TV story to `/airo/tv/`, where visitors can evaluate, download, set up, and
follow the active product without confusing it for the whole platform.

This is an information-architecture and public-copy change. It does not change
the Flutter/Rust runtime, Airo TV releases, or provider support.

## Critical Agent Clarity Gate

| Question | Decision |
| --- | --- |
| User journey | A visitor can identify Airo as a modular platform in under 30 seconds, then choose Airo TV when they want a media product. |
| Owners | Chief Documentation Officer owns public information architecture; Product Manager owns positioning and claim priorities; Chief UX Officer reviews accessibility and responsive behaviour; Chief Release/DevOps Officer verifies release/download evidence. |
| Impacted modules | GitHub Pages source under `docs/`, public release/guides copy, shared CSS/JS/assets. No application code is in scope. |
| Change class | Application/public-product communication. It represents framework architecture but does not modify framework code. |
| Cross-agent contract | The root page may describe reusable foundations only; `/tv` may make Airo TV product claims only when release evidence proves them. The two pages share visual tokens and claim-state badges, but not product-specific content. |
| Data/privacy | No new collection. Any retained live demo must require an explicit play action, disclose the external host, and never proxy/cache/rebroadcast media. |
| Failure behaviour | A missing release asset leaves the download CTA disabled or directs to Releases with an honest status; unavailable demos show a manual retry state. |

## Evidence and Publication Gate

Before copy or page implementation, the release owner must reconcile this
previously conflicting evidence:

- `docs/index.html` describes **Airo TV v0.0.3** as available.
- `docs/release/AIRO_TV_FEATURE_MATRIX.md` still says its unshipped items are
  “not included in v0.0.2”.
- `app/pubspec_iptv.yaml` and `app/pubspec_streaming.yaml` currently use
  `0.0.3-rc.1+3`.

The release owner must inspect the published GitHub release assets/notes,
checksums, and current qualification matrix, then choose one public state:

1. **Available (v0.0.3):** update matrices and use a direct download CTA.
2. **Under qualification / release candidate:** replace “available” with the
   precise qualifier and direct visitors to validation artifacts only where
   approved.
3. **No public v0.0.3 release:** use the latest published version and remove
   v0.0.3 from public copy.

Resolution recorded during implementation: the published non-prerelease
`airo-tv-v0.0.3` release provides Android TV assets, checksums, and known
limitations. The feature matrix now uses v0.0.3 as its public reference. No
page should publish a device, provider, performance, or Pro claim that is not
supported by this evidence. Airo TV provides no channels, playlists,
subscriptions, or media catalog.

## Information Architecture

```text
/airo/                                      Platform home
├── Platform overview                         What Airo is; why modules
├── Architecture                              App / platform / provider layers
├── Shared foundations                        Flutter UI, native performance, AI/runtime,
│                                              plugins, packs — each with evidence state
├── Module map                                Airo TV is active; other module areas are
│                                              clearly labelled exploration/planned
├── Community                                 Plugins, packs, themes, extensions (direction)
├── Platform roadmap                          Linked public evidence; no delivery dates
└── Airo TV reference                         One concise hand-off to /airo/tv/

/airo/tv/                                   Product home
├── Product value                             BYOC media player; explicit content boundary
├── Current release / download                Evidence-backed device and release status
├── Product journey                           Add source → browse/search → play
├── Screens and capabilities                  Sanitized release screenshots; shipped vs planned
├── Providers and compatibility               Only verified support, limitations included
├── Setup and documentation                   Device guides, FAQ, troubleshooting
├── Community Voice / product roadmap         Public issues and clear status labels
├── Airo TV Pro                               “In testing” only; approved outcome copy
└── Trust and source code                     Privacy, terms, checksums, GitHub
```

## Core Design Decisions

### 1. Root page is the platform, not a TV landing page

The root hero becomes:

> **Airo**
> Build focused experiences on a modular, local-first platform.

Supporting copy should describe the platform through real architecture — Flutter
UI, reusable core/platform packages, and the `core_native` bridge to the Rust
core — without presenting internal implementation names as customer features.
The primary calls to action are **Explore the platform**, **Read the
architecture**, and **View Airo TV**. Download belongs to `/tv`.

Remove from `/airo/`: Airo TV screenshots as hero art, live-stream players,
TV device matrices, product guides, detailed Pro feature lists, and IPTV
research navigation. Those become `/tv` content or linked documentation.

### 2. The module map makes scale visible without fabricating products

Use the requested category structure as a visual map, not a flat launch list:

| Group | Module area | Public state for this redesign | Copy rule |
| --- | --- | --- | --- |
| Media | Airo TV | Available only after release audit | Link to `/tv/`; include current release proof. |
| Media | Airo TV Pro | In testing | Outcome-level copy only; no price, timing, entitlement, or private implementation. |
| Media | Music | Exploring / planned | One sentence; no availability implication. |
| AI | AI | Exploring / planned | Describe platform direction, not a released chat product. |
| Productivity | Money | Exploring / planned | Do not claim a public finance product or financial advice. |
| Productivity | Reader | Exploring / planned | Do not claim OCR or document intelligence as available. |
| Entertainment | Games | Exploring / planned | Do not imply Stockfish is bundled or available unless release evidence says so. |

Important brand decision: the publication policy says non-TV capabilities remain
part of Airo and must not become separate public product brands without an
approved brand decision. Therefore the first version should use labels such as
**AI**, **Money**, **Music**, **Games**, and **Reader** under “Airo modules”,
not “Airo AI”, “AiroMoney”, etc. The requested branded names can be promoted
only after product leadership explicitly approves them.

### 3. `/tv` sells the product through proof, not a feature wish list

The TV hero should use a current, authorized screenshot and position the
product as a bring-your-own-content media player. Recommended direction:

> **Your sources. Your screen.**
> Airo TV is a remote-first player for media sources you are authorized to use.

The hierarchy is: product promise → verified release → three-step product
journey → features with status → compatibility → guides → Community Voice →
Pro → trust. It keeps setup and product evaluation clear while preserving
Airo’s disclosure and qualification standards.

### 4. Documentation is task-oriented and separate from marketing

Keep the existing `/airo/airo-tv/guides/` material initially, but expose it at
`/airo/tv/guides/` through a moved source or compatibility redirect. It should
open with a short quick start and then offer: Install, Add a source, Browse and
search, Cast, Supported devices, Troubleshooting, and FAQ. Keep the product
page concise, with a navigable task tree instead of an undifferentiated
documentation dump.

## Content System

Every capability card, device row, provider statement, and roadmap entry gets
one of these visible states: **Available**, **Under qualification**,
**In testing**, **Planned**, **Deferred**, or **Not supported**. A state must
link to its evidence when a public issue, matrix, or release record exists.

Do not use these unverified claims in the first pass: “runs everywhere”,
Jellyfin/Plex/Emby/YouTube support, cloud sync, profiles, recommendations,
offline metadata cache, PiP, multiview, native decoding, low memory, fast
startup, hardware acceleration, or numeric performance claims. The current
feature matrix publicly proves M3U/M3U8, channel search, Android TV, and
Chromecast controls; the build/qualification sources determine the rest.

## Delivery Plan

### Phase 1 — Evidence and page contract

1. Create one public-site feature packet/issue with the claim inventory,
   exact release state, screenshot rights, target audiences, and analytics
   decision (default: no new tracking).
2. Reconcile v0.0.3 release evidence and update affected release documents
   before changing marketing copy.
3. Write a compact content contract: allowed terminology, nav map, CTA map,
   claim-state source, redirect map, and “no channels” disclosure.

**Checkpoint:** Product, Documentation, UX, and Release owners approve the
content contract and the public release state.

### Phase 2 — Root platform experience

4. Extract shared tokens/navigation/footer from the existing single page.
5. Replace `docs/index.html` with the platform story, architecture diagram,
   foundation ledger, module map, community direction, roadmap, and concise TV
   hand-off.
6. Add accessible static fallbacks for the architecture/module visuals and
   avoid interactive expansion as the sole way to read content.

**Checkpoint:** Root visitors can explain platform → modules → Airo TV without
encountering IPTV setup, live media, or unqualified product claims.

### Phase 3 — Airo TV product experience and documentation

7. Create `docs/tv/index.html` using the shared shell and move all detailed TV
   story elements from the root page, removing duplication.
8. Build evidence-backed release/download, device, provider, capability, and
   trust sections; keep live samples disabled by default unless re-approved.
9. Move or redirect TV guides to `/tv/guides/`, preserve current inbound links,
   and add a short quick-start route.

**Checkpoint:** A visitor can download/setup Airo TV from `/tv`, and every old
root TV URL either works or has a clear destination.

### Phase 4 — Audit and publication readiness

10. Run the branding audit, link checker, and local GitHub Pages build.
11. Check keyboard navigation, focus order, 44px targets, no horizontal
overflow, static/reduced-motion fallbacks, and screenshots at 1920x1080,
1280x720, 1024x576, and 390x844.
12. Compare root and TV page screenshots to the current site and record all
claim changes/withheld claims in the issue. Do not deploy without explicit
maintainer approval.

## Verification Contract

Deterministic checks for the implementation issue:

1. **Root routing:** visiting `/airo/` shows Airo platform navigation and one
   `/tv/` hand-off; it contains no live player or TV-only installation flow.
2. **TV routing:** visiting `/airo/tv/` presents current product evidence,
   download/release status, setup guides, trust boundary, and source link.
3. **Claim integrity:** every Available claim maps to released artifact
   evidence; each non-available module/card carries a visible qualifier.
4. **Content boundary:** no page claims Airo TV provides channels or a
   subscription; no third-party manifest is requested before a visitor action.
5. **Compatibility:** legacy guide/root anchors retain a working target or a
   permanent redirect; internal links have no 404s.
6. **Accessibility/responsiveness:** keyboard-only navigation succeeds; targets
   are at least 44px; four required viewports have no overlap or horizontal
   scrolling; reduced motion leaves all content usable.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| v0.0.3 release evidence remains inconsistent | High | Block “Available” copy until release, matrix, checksums, and qualification data agree. |
| Future modules look like shipping commitments | High | Use a clearly labelled “Exploring” state and no download/CTA for them. |
| Airo TV Pro exposes private commercialization details | High | Keep only approved customer-outcome copy and the “In testing” state. |
| Existing inbound links break | Medium | Maintain redirects/anchors and run a link crawl before deploy. |
| Root and product page drift | Medium | Share navigation, design tokens, claim-state component, and a short content contract. |
| Third-party demos create privacy/copyright risk | High | Prefer owned screenshots; retain a demo only with fresh approval and explicit-play disclosures. |

## Open Decisions for Product Leadership

1. Approve whether the non-TV names become public product brands or stay module
   areas under Airo for this release.
2. Confirm the actual public Airo TV release/version and which download assets
   are approved for the new `/tv` CTA.
3. Decide whether live-stream demos remain on `/tv`; recommendation: remove
   them for the first split and use authorized screenshots/video instead.
4. Decide whether “Flutter + Rust + AI SDK” is audience-facing language or
   whether root-page copy should lead with outcomes and keep implementation
   detail in Architecture.
5. Confirm which channels the community should use (GitHub Issues/Discussions,
   Discord, etc.) before adding social/support CTAs.
