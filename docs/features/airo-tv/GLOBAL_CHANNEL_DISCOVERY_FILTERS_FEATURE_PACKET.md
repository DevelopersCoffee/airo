# Global Channel Discovery Filters Feature Packet

## Feature Packet

**Primary owner agent:** Airo TV Flutter Architect
**Review agents:** Media Intelligence Architect, Chief UX Officer, Chief QA Officer
**Layer:** Shared IPTV application presentation; no playlist, EPG, or platform
adapter schema changes.
**Sprint:** Airo TV phone discovery follow-up
**Parent roadmap:** Airo TV v2 release qualification

### Critical Agent Gate

**Problem:** The compact Airo TV browser displays raw country and language
codes, provides a second search control alongside the app-bar search, and
does not show the channel artwork already supplied by playlists. More
importantly, country/language filtering only works for channels that happen to
match a remote enrichment response, and its scope is not carried into the
EPG guide.

**User / actor:** An Airo TV phone, tablet, desktop, or TV user narrowing a
large playlist by market and language before selecting a channel or opening
the guide.

**Framework or application layer:** Application presentation and the existing
shared filter provider. Playlist parsing, XMLTV loading, worker boundaries,
and platform adapters are unchanged.

**Owning agent:** Airo TV Flutter Architect.

**Reviewing agents:** Media Intelligence Architect (playlist/EPG filter
contract), Chief UX Officer (compact discovery), Chief QA Officer (provider
and widget regression coverage).

**Impacted modules/files:** `feature_iptv` channel-filter provider, Guide
provider, compact filter row, channel table/info bar, focused tests, and this
feature packet.

**Base branch/worktree:** Yes — the worktree is based on fetched `origin/main`
at `5b61c8bb`.

**Decision:** Ready. Country is the parent, global scope; language options are
limited to the selected country. A channel's verified enrichment value wins,
with the playlist model as the safe fallback. The existing app-bar search is
the sole search entry point for the compact product, so the duplicate filter
row search chip is removed.

### Cross-Agent Contract

**Provider agent:** `feature_iptv` channel discovery provider.
**Consumer agents:** compact Airo TV browser and XMLTV Guide.
**Interface/API:** `ChannelFilters`, `channelFilterDimensions`,
`applyChannelFilters`, and `applyChannelScope`.
**Inputs:** Playlist `IPTVChannel.country` / `languages`; optional matched
metadata; user-selected country and language.
**Outputs:** Display-ready country/language dimensions and consistently scoped
channel lists.
**State changes:** Explicit country selection clears a previous language
selection; preferences continue to use the existing keys.
**Errors:** Missing or malformed metadata falls back to playlist values;
unknown ISO values remain visible instead of being discarded.
**Persistence:** Existing shared-preferences filter keys only.
**Privacy:** No data is transmitted or logged by this change.
**Versioning/migration:** None; existing saved filters retain their raw ISO
values.

### Deterministic Use Cases

#### UC-001: Browse a country then a language

**Given:** A playlist includes channels in India/English and Italy/Italian.
**When:** The user selects Italy and then Italian.
**Then:** The visible browse list contains only the Italian channel, and the
language picker offers only languages found in Italy.
**Failure path:** If enrichment is unavailable, the playlist model values keep
the same controls functional.

#### UC-002: Retain regional scope in the EPG guide

**Given:** A global country/language scope is active.
**When:** The user opens Guide.
**Then:** The guide grid shows only channels in that scope while its local
guide-search text stays independent.

#### UC-003: Identify a compact-list channel at a glance

**Given:** A compact browser row for a playlist channel.
**When:** The row is rendered.
**Then:** It displays the playlist logo or the existing deterministic fallback,
plus human-readable country and language context.

### Automation Flow

#### AUTO-001: Global scope regression

**Environment:** Host-only provider and widget tests; Pixel 9 smoke test.
**Given:** Mixed-country fixture data with no remote enrichment.
**When:** Country and language filters are selected.
**Then:** Browse dimensions and results use playlist fallback values, language
is narrowed by country, and Guide respects the same region/language scope.
**Assertions:** No compact search filter chip is present; country appears
before language; labels are user-readable; channel-logo widget is rendered.
**Cleanup:** Provider containers and shared-preferences fixtures are disposed.

### Implementation Boundaries

- **Framework files:** None.
- **Application files:** `feature_iptv` provider and presentation only.
- **Tests:** Focused `channel_filters`, Guide provider, filter-row, and
  channel-table tests.
- **Docs:** This feature packet only.
- **Verification environment:** Focused Flutter tests, analyzer, Pixel 9
  compact-product smoke test, and `git diff --check`; no remote CI.
