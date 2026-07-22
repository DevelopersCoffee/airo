# Category Filter Deduplication Feature Packet

## Feature Packet

**Primary owner agent:** Media Intelligence Architect
**Review agents:** Airo TV Flutter Architect, Chief UX Officer, Chief QA Officer
**Layer:** `feature_iptv` application filter presentation.
**Sprint:** Airo TV phone discovery follow-up
**Parent roadmap:** Airo TV v2 release qualification

### Critical Agent Gate

**Problem:** Playlist groups that differ only by case or spacing are presented
as separate category choices. Selecting one spelling currently excludes the
equivalent spelling, creating duplicate categories and unexpected results.

**User / actor:** Airo TV user narrowing a playlist by category.

**Framework or application layer:** Application filtering. Playlist data and
the `IPTVChannel.group` schema remain lossless and unchanged.

**Owning agent:** Media Intelligence Architect (`feature_iptv`).

**Reviewing agents:** Airo TV Flutter Architect, Chief UX Officer, Chief QA
Officer.

**Impacted modules/files:** Shared channel-filter dimensions and matching,
focused provider test, and this feature packet.

**Base branch/worktree:** Yes — the current task worktree is based on fetched
`origin/main` at `5b61c8bb`.

**Open questions:** None. “Deduplicate” is limited to whitespace and
case-equivalent labels. It must not merge distinct editorial labels such as
`News` and `World News`.

**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** `feature_iptv` channel filter provider.
**Consumer agent:** Airo TV category picker and browse list.
**Interface/API:** Existing `channelFilterDimensions` and
`applyChannelFilters`.
**Input shape:** Raw `IPTVChannel.group` strings and an optional selected
category.
**Output shape:** One first-seen, trimmed display label for each normalized
case/whitespace category; matching channels for all equivalent labels.
**State changes:** No new state or persistence. Existing saved category values
continue to work through normalized comparison.
**Errors:** Empty group labels retain existing `IPTVChannel` normalization and
are not introduced as choices.
**Permissions/privacy/persistence:** None beyond the existing local filter
preference.
**Versioning/migration:** None.
**Tests required:** Assert equivalent groups render once and a selected
canonical category includes all equivalent source values.

### Deterministic Use Case

#### UC-001: Select a deduplicated News category

**Given:** A playlist contains `News`, ` news `, and `NEWS`, plus `Sports`.
**When:** The user opens Category and selects News.
**Then:** The picker shows News once and the browse list contains all three
News channels, but not Sports.
**Data created/updated/deleted:** None.
**Privacy expectations:** No playlist data is transmitted or mutated.

### Automation Flow

#### AUTO-001: Equivalent category regression

**Environment:** Host-only provider test.
**Given:** Deterministic mixed-case/spacing category fixtures.
**When:** Dimensions and filtered results are evaluated.
**Then:** Dimensions contain one News label and category filtering includes all
equivalent source values.
**Cleanup:** No stateful resources.

### Implementation Boundaries

- **Framework files:** None.
- **Application files:** `feature_iptv` channel-filter provider only.
- **Tests:** `channel_filters_provider_test.dart`.
- **Docs:** This feature packet only.
- **Verification environment:** Focused Flutter test, analyzer, and
  `git diff --check`; no remote CI.
