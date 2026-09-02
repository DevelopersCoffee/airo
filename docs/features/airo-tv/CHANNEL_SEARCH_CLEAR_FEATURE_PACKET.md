# Channel Search Clear Feature Packet

## Feature Packet

**Primary owner agent:** Media Intelligence Architect
**Review agents:** Midas Stream Flutter Architect, Chief UX Officer, Chief QA Officer
**Layer:** `feature_iptv` application filter presentation.
**Sprint:** Midas Stream phone discovery follow-up
**Parent roadmap:** Midas Stream v2 release qualification

### Critical Agent Gate

**Problem:** After a channel search is applied, the query remains active in the
library filter row without a direct clear action. On a compact phone viewport,
users can be left with a very small result set and no obvious way to restore
the complete, scrollable channel library.

**User / actor:** Midas Stream user searching a channel library on phone, tablet,
desktop, or TV.

**Framework or application layer:** Application presentation. Channel models,
search indexing, storage schemas, and platform contracts are unchanged.

**Owning agent:** Media Intelligence Architect (`feature_iptv`).

**Reviewing agents:** Midas Stream Flutter Architect, Chief UX Officer, Chief QA
Officer.

**Impacted modules/files:** Responsive filter row, search overlay, focused
widget tests, and this feature packet.

**Base branch/worktree:** Yes — the task worktree is based on current
`origin/main` at `43a0109e`.

**Open questions:** None. Clearing search removes only the search text; active
category, country, and language filters remain intact.

**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Existing `feature_iptv` channel filter provider.
**Consumer agent:** Midas Stream channel-library filter row and search overlay.
**Interface/API:** Existing `ChannelFiltersNotifier.setSearch`.
**Input shape:** A locally entered channel-search string.
**Output shape:** Existing filtered channel list, or the complete list within
the remaining active filters when search is cleared.
**State changes:** The existing persisted search preference is set to an empty
string. Other filters are retained.
**Errors:** Preference-write failures retain the existing in-memory fallback
behavior and do not block browsing.
**Permissions/privacy:** No new permissions, logging, or transmission.
**Persistence:** Existing shared-preferences key only; no migration.
**Versioning/migration:** None.
**Tests required:** Assert the clear control appears only for an active query,
is labeled, and clears search without clearing other filters.

### Deterministic Use Cases

#### UC-001: Restore the channel library after search

**Actor:** Midas Stream user on a compact Pixel 9 viewport or TV.
**Preconditions:** A channel query is active and the library shows matching
results.
**Trigger:** The user activates `Clear search`.
**Happy path:** Search text clears immediately, the clear action disappears,
and the channel library restores every channel allowed by the remaining
filters.
**Alternate path:** The user clears the query inside the open search field and
continues browsing or closes the overlay.
**Failure path:** A preference-write failure does not prevent the in-memory
library from being restored.
**Data created/updated/deleted:** The existing local search preference is
updated to an empty string.
**Privacy expectations:** Search text remains local and is never logged or
transmitted by this change.

### Automation Flow

#### AUTO-001: Clear active channel search

**Environment:** Host-only Flutter widget test; Pixel 9 physical-device smoke
test remains a follow-up if the device is unavailable.
**Given:** A provider container with an active search and another active filter.
**When:** The user taps or selects the labeled clear-search control.
**Then:** Search is empty, the other filter is unchanged, and the clear control
is removed from the filter row.
**Fixtures:** Mock shared preferences and deterministic channel-filter state.
**Assertions:** Visible label/tooltip, provider state, retained category, and
conditional control visibility.
**Cleanup:** Dispose the provider container.

### Implementation Boundaries

- **Framework files:** None.
- **Application files:** `feature_iptv` filter-row and search-overlay widgets.
- **Tests:** Focused filter-row widget tests.
- **Docs:** This feature packet only.
- **Verification environment:** Focused Flutter tests, analyzer,
  `git diff --check`; no remote CI.
