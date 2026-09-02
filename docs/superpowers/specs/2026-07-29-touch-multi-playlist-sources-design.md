# Touch multi-playlist source management

Date: 2026-07-29
Status: Ready

## Feature packet

**Primary owner agent:** Media Intelligence Architect

**Review agents:** Product Manager, Chief Architect, Platform Architect, Chief
QA Officer, Flutter Architect, Chief Performance Officer

**Layer:** Mixed (`platform_playlist_import` cache boundary and
`feature_iptv` workflow/UI)

**Base branch/worktree:** `origin/main` at
`271603c0`, confirmed in
`airo-worktrees/multi-playlist-touch`

### Critical Agent gate

**Problem:** A touch-device user can configure only one legacy M3U URL. The
existing content-source store accepts multiple M3U records, but those records
are exposed only in the TV settings surface and are not loaded into the live
channel library.

**User / actor:** Phone and tablet users managing authorized IPTV playlists,
including the public playlist variants documented by iptv-org.

**Framework or application layer:** Mixed. Per-source cache isolation belongs
to `platform_playlist_import`; source management, migration, aggregation, and
touch presentation belong to `feature_iptv`.

**Impacted modules/files:** `platform_playlist_import`,
`feature_iptv`, focused tests, and this design record.

**Data lifecycle:** Source labels and URLs are stored locally. Parsed channel
caches and HTTP validators are stored separately for each source. Removing a
source removes its configuration and its cache. No source URL is added to
logs, analytics, or remote sync.

**Offline/failure behavior:** Each source may fall back to its own valid cache.
A failed source does not hide channels loaded from other sources. An empty
configuration shows the existing recovery state.

**Decision:** Ready.

### Cross-agent contract

**Provider agent:** Media Intelligence Architect

**Consumer agent:** Midas Stream Flutter application

**Interface/API:** `M3UParserService` accepts an optional stable source
namespace. Existing callers that omit it retain legacy keys and filenames.

**Input shape:** A validated HTTP(S) M3U URL plus a local source ID.

**Output shape:** Normalized `List<IPTVChannel>` per source.

**State changes:** Namespaced URL, timestamp, ETag, Last-Modified, and parsed
channel cache.

**Errors:** A source fetch failure produces an empty list or its own cache;
other sources continue loading.

**Permissions:** Existing network permission only.

**Privacy/redaction:** URLs and playlist contents are not logged.

**Persistence:** Existing single URL is represented as the first named source
without deleting the legacy value, preserving rollback compatibility.

**Versioning/migration:** Additive and backward compatible; no schema rewrite.

**Tests required:** namespace isolation, legacy compatibility, migration,
multi-source aggregation/deduplication, add/remove touch journey, validation,
and 48 dp touch targets.

### Deterministic use cases

#### UC-001: Preserve an existing Pixel 9 playlist

**Given:** `iptv_user_playlist_url` contains a valid playlist.

**When:** the channel library or source manager opens after upgrade.

**Then:** the URL appears as a named source and its channels remain available.

#### UC-002: Add several iptv-org playlist variants

**Given:** one source is already configured.

**When:** the user adds any valid URL documented in `PLAYLISTS.md`, such as
category, language, country, region, or split playlist URLs.

**Then:** the source is stored independently and its channels are combined
with the existing library.

#### UC-003: Remove one source safely

**Given:** two sources are configured.

**When:** the user confirms removal of one source.

**Then:** only that source and its cache are removed; the other source remains
usable.

#### UC-004: Isolate a failing source

**Given:** one source is unreachable and another succeeds or has a cache.

**When:** channels refresh.

**Then:** channels from the usable source remain visible and no private URL is
shown in diagnostics.

### Automation flow

#### AUTO-001: Host-only provider and widget verification

**Given:** in-memory preferences, two local M3U fixtures, and a touch-size
viewport.

**When:** the source manager adds/removes sources and the channel provider
loads them.

**Then:** source rows, combined unique channels, persistence, cleanup,
validation copy, and touch targets match the use cases.

#### AUTO-002: Pixel 9 qualification

**Given:** the physical Pixel 9 and an existing primary playlist.

**When:** a second authorized playlist is added from the playlist action.

**Then:** both named sources remain manageable after relaunch and channels
from both are browsable. This device pass may follow host validation when the
rig is unavailable.

## UX contract

- The playlist app-bar action opens a manager, not a single-URL editor.
- Existing sources are visible as named rows with a source count.
- Add uses label and URL fields, keyboard-safe scrolling, inline validation,
and at least 48 dp actions.
- Remove requires confirmation and never removes a sibling source.
- iptv-org is an example provider, not a hard-coded dependency: every
standards-compliant HTTP(S) M3U URL remains accepted.

## Out of scope

- Downloading or scraping `PLAYLISTS.md` at runtime.
- Bundling channels or private provider credentials.
- Changing Xtream, Stalker, Jellyfin, XMLTV, playback, or TV remote behavior.
- Remote sync of source URLs.
