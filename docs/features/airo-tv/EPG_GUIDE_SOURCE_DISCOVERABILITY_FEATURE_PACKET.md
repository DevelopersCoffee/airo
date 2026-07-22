# EPG Guide Source Discoverability Feature Packet

## Feature Packet

**Primary owner agent:** Airo TV Flutter Architect
**Review agents:** Media Intelligence Architect, Chief UX Officer, Chief QA Officer
**Layer:** Application/domain UI; uses the existing XMLTV source contract unchanged.
**Sprint:** Airo TV phone usability follow-up
**Parent roadmap:** Airo TV v2 release qualification

### Critical Agent Gate

**Problem:** On phone-sized Airo TV, the Guide route explains that an XMLTV
source must be added in Settings, but the compact Airo TV shell exposes no
Settings entry. The reusable XMLTV source sheet still exists, but its direct
product entry point is missing. This makes the EPG guide appear unavailable.

**User / actor:** Airo TV phone user configuring an IPTV playlist and guide.

**Framework or application layer:** Application/domain UI. No EPG parsing,
storage schema, permissions, or platform adapter changes are needed.

**Owning agent:** Airo TV Flutter Architect.

**Reviewing agents:** Media Intelligence Architect (existing XMLTV contract),
Chief UX Officer (compact navigation), Chief QA Officer (regression coverage).

**Impacted modules/files:** `feature_iptv` IPTV screen toolbar and its focused
widget test; this feature packet.

**Base branch/worktree:** Yes — the task worktree was resynced to fetched
`origin/main` at `5b61c8bb` before implementation.

**Open questions:** None. The user specified the required phone toolbar order:
Search, Playlist URL, Guide URL, Cast.

**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Media Intelligence Architect / `feature_iptv` XMLTV source
sheet.
**Consumer agent:** Airo TV Flutter Architect / phone `IPTVScreen` toolbar.
**Interface/API:** Existing `showXmltvSourceSheet(BuildContext)`.
**Input shape:** Explicit user tap on the Guide URL toolbar action.
**Output shape:** Existing XMLTV URL entry sheet.
**State changes:** Only an explicit Save & Refresh in the existing sheet may
write the already-defined XMLTV source preference. Opening or dismissing the
sheet changes nothing.
**Errors:** Existing sheet reports refresh failures and retains its existing
source behavior.
**Permissions:** No new permissions.
**Privacy/redaction:** The guide URL remains local to the existing preference
store; no new logging or transmission path.
**Persistence:** Existing `XmltvSourceStore` only.
**Versioning/migration:** None.
**Tests required:** Assert the Guide URL action is visible on the compact Airo
TV toolbar and opens the XMLTV source sheet without saving a source.

### Deterministic Use Cases

#### UC-001: Configure an EPG guide from the phone toolbar

**Actor:** Airo TV phone user.
**Preconditions:** Airo TV opens with an IPTV playlist and no XMLTV source.
**Trigger:** Tap Guide URL.
**Happy path:** The XMLTV Guide Source sheet presents the existing URL field
and Save & Refresh action.
**Failure path:** Dismissing the sheet leaves no source configured.
**Data created/updated/deleted:** No data until the user explicitly saves a
URL; dismissal creates no data.
**Privacy expectations:** The URL is user-provided and handled by the existing
local XMLTV-source workflow.

### Automation Flow

#### AUTO-001: Guide URL toolbar regression

**Environment:** Host-only widget test; physical Android device verification
on Pixel 9.
**Given:** A compact Airo TV `IPTVScreen` with no XMLTV source configured.
**When:** The user taps the Guide URL toolbar action.
**Then:** The XMLTV Guide Source sheet is visible and reports that no source is
configured.
**Fixtures:** Existing in-memory shared-preferences fixture.
**Mocks/stubs:** Existing IPTV provider overrides.
**Assertions:** Search, Playlist URL, Guide URL, and Cast actions are present;
dismissing Guide URL writes no XMLTV source.
**Cleanup:** Widget teardown disposes the test provider scope.

### Implementation Boundaries

- **Framework files:** None.
- **Application files:** `feature_iptv` compact IPTV toolbar only.
- **Tests:** `iptv_screen_test.dart`.
- **Docs:** This feature packet only.
- **Verification environment:** Host-only Flutter test, analyzer, and Pixel 9
  physical-device smoke test. No emulator and no remote CI.
