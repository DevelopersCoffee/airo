# Airo TV Unified Browse Experience — Design Spec

**Date:** 2026-07-19
**Status:** Approved pending user review
**Source design:** Claude Design handoff bundle (`AiroTV-handoff.zip`, `Airo TV.dc.html`) — dark green-accent theme, rail-based browse, minimal player overlay.
**Supersedes:** current split mobile/TV IPTV browse screens (`iptv_screen.dart`, `iptv_tv_screen.dart` browse portions).

## 1. Goal

One browse experience across Phone / Tablet / TV / Desktop, rendered from a generated rail list. Netflix-style horizontal rails with Airo's own visual identity. UI is a dumb renderer: rails, ranking, and personalization come from the Media Engine and (later) the Edge Intelligence SDK — the Flutter layer never changes when intelligence improves.

## 2. Design language (from handoff mockup)

Tokens (add to `core_ui` theme as an `AiroTvTheme` extension; oklch values converted to nearest `Color` at build time):

| Token | Value | Use |
|---|---|---|
| `bg` | `oklch(0.09 0.010 255)` | app background |
| `surface` | `oklch(0.135 0.010 255)` | sidebar, cards |
| `surface2` | `oklch(0.175 0.010 255)` | hover/pressed |
| `border` | `oklch(0.245 0.015 255)` | card/nav borders |
| `accent` | `oklch(0.62 0.19 145)` (green) | CTAs, active nav, logo |
| `accentDim` | `oklch(0.22 0.07 145)` | accent-tinted chips/callouts |
| `gold` | `oklch(0.77 0.13 78)` | quality badges |
| `live` | `oklch(0.60 0.18 25)` (red) | LIVE badges |
| `text` | `oklch(0.94 0.008 255)` | primary text |
| `textMuted` | `oklch(0.52 0.012 255)` | secondary text |

Typography: DM Sans (bundle as asset font; fallback system-ui). Radii 8–20px. Card: 172px wide, 104px art area, initials fallback, LIVE badge top-left, quality badge top-right (gold, blurred dark pill).

## 3. Navigation model

Identical destination set everywhere: **Home, Live, Guide, Favorites, Settings.**

- **TV / Desktop / Tablet-landscape:** left rail, 88px (60px at ≤700px logical width). Active item: green icon + 3px left accent bar. Logo block on top, "devs coffee" credit at bottom.
- **Phone (≤440px logical width):** 5-item bottom navigation bar, same destinations, same order. No drawer.
- Wire through existing `adaptive_navigation.dart` / `AiroResponsiveScaffold` breakpoint machinery; restyle, do not rebuild.

## 4. Architecture

### 4.1 Rail generation (Media Engine)

Rails are generated, never hardcoded. New package-level API (lives in Media Engine layer — `core_media_data` or a new `platform_rails`; final home decided in plan phase with chief-architect review):

```dart
class RailDefinition {
  final String id;          // 'top-india', 'live-sports', ...
  final String title;
  final String? subtitle;
  final IconData? icon;
  final RailQuery query;    // declarative filter/sort spec
  final int priority;       // display order
  final RailVisibility visibility; // always | whenNonEmpty | hidden
  final RailLayout layout;  // card variant + density
}

abstract class RailProvider {
  Future<List<Channel>> buildRail(RailDefinition rail);
}
```

`RailQuery` is declarative (category/language/liveness/EPG-now filters + sort key) so the intelligence layer can add/reorder/redefine rails without Flutter changes.

Initial rail set (v1): Top India, Live Sports, Movies On Now, Hindi News, Favorites, Recently Added. Definitions supplied by a `DefaultRailCatalog` in the Media Engine; UI renders whatever list arrives.

**Popularity score v1:** `favorites + watch history + provider order`, degrading gracefully to provider order only when history is empty. Score computation lives behind `RailProvider`; later replaced by regional popularity / trending / AI recommendations / collaborative ranking with zero UI change.

**Layer split (locked):**
- **Media Engine** builds rails from playlist metadata, EPG, watch history, provider data.
- **Edge Intelligence SDK** personalizes, reorders, filters, recommends those rails.
- Flutter renders the received `List<RailDefinition>` + channels. Nothing else.

### 4.2 MediaCard — one reusable card

Single `MediaCard` widget in `core_ui` with a `MediaCardVariant` enum: `compact`, `standard`, `hero`, `landscape`, `portrait`, `continueWatching`, `live`. No per-content-type card widgets. Variant controls size, art aspect, badge set, progress bar. Focus behavior (TV): scale + green border + shadow on focus, matching mockup hover treatment.

### 4.3 Player overlay — renderer-agnostic

Overlay depends only on published state, never on ExoPlayer/VLC types:

```dart
PlayerState { PlaybackState playback; List<TrackInfo> tracks;
              BufferState buffer; StreamHealth health; QualityState quality; }
```

Backend (platform_player) publishes; Flutter renders. Overlay elements from mockup:
- Top gradient: back button, title/subtitle, `StreamHealth` pill ("Good · Auto"), LIVE pill.
- Center: previous / play-pause (62px white) / next.
- Failover toast: "Switching to source N of M" — driven by `StreamHealth` source-switch events.
- Bottom gradient: scrubber (red, thumb at live edge), "● LIVE" + buffer seconds, volume / Guide / fullscreen buttons.
- Auto-hide after 3s of inactivity; any pointer/DPAD event reveals.

### 4.4 Playlist import pipeline

Staged pipeline, each stage reporting progress independently:

```
Import → Validate → Download → Parse → Normalize → Deduplicate → Index → Generate Rails → Persist → Ready
```

Exposed as `Stream<ImportProgress>` (stage enum + 0..1 fraction + optional message). Supports very large playlists and future background imports without UI redesign. The Add Playlist modal subscribes and shows stage progress.

## 5. Screens

1. **Empty state** — centered logo + tagline, "Add Playlist URL" CTA, four checkmark value props (no account, dead links removed, duplicates merged, smart rails), "Preview with demo playlist →" link, ambient green glow.
2. **Browse (Home/Live)** — top bar: screen title, "N channels · <freshness>" line, Search button, Playlist button. Category chips row with counts (green-filled when active). Vertically scrolling rail list; each rail: title + subtitle, horizontally scrolling `MediaCard`s.
3. **Player** — full-bleed video + overlay per §4.3.
4. **Add Playlist modal** — URL input, green dedupe-promise callout, Remove / Cancel / Save; restyles existing `_PlaylistSourceSheet` content and adds pipeline progress.
5. **Now Playing mini bar** — persistent bottom bar (above bottom nav on phone) when playing while browsing: art tile, name/category, LIVE pill, Watch button, dismiss.

## 6. Responsive adaptation

Only these vary by form factor: navigation (rail vs bottom bar), spacing, focus behavior (touch vs DPAD), card sizes, typography scale, overscan margins (TV: standard 5% safe area). Everything else — rails, cards, player, modal — identical widgets.

## 7. Delivery plan (one thread, dogfood after each chunk)

1. **Chunk 1 — Foundation:** `AiroTvTheme` tokens + DM Sans, adaptive nav restyle (rail + bottom bar), empty state screen.
2. **Chunk 2 — Rails:** `RailDefinition`/`RailProvider`/`DefaultRailCatalog` in Media Engine, `MediaCard` in core_ui, Browse screen rendering rails + category chips.
3. **Chunk 3 — Player:** renderer-agnostic `PlayerState` surface, overlay UI, now-playing mini bar.
4. **Chunk 4 — Import:** pipeline stages + progress stream, restyled Add Playlist modal.

Each chunk: widget tests for new components, existing IPTV tests kept green, on-device dogfood (macOS + phone; TV via run-airo-tv skill) before starting next chunk. Old browse code paths removed only after chunk 2 dogfood passes.

Review gates: chief-architect (package boundaries, chunk 2), tv-experience-architect (focus/overscan, chunk 2+3), playback-architect (PlayerState contract, chunk 3), chief-ux-officer (nav model, chunk 1).

## 8. Error handling

- Rail build failure: rail hidden (`whenNonEmpty` semantics), error logged; browse never blanks.
- Import pipeline stage failure: stage-specific error in modal with retry; partial results discarded.
- Player source failure: failover toast, auto-advance to next source; terminal failure returns to browse with snackbar.

## 9. Out of scope (v1)

- Real regional popularity / trending / AI ranking (interface only).
- Continue Watching rail (needs core_watch_progress wiring — rail definition reserved, hidden).
- Downloads, New & Hot destinations.
- EPG "Movies On Now" precision beyond current EPG match quality.
