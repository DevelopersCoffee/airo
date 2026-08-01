# Shared Channel Import and App-Link Opening — Design

**Status:** Implemented locally; domain association and physical-device qualification pending
**Date:** 2026-07-29
**Release tier:** Standard feature (Community Edition; no Pro entitlement)
**Base:** rebased onto `origin/main` at `dc7406d6`
**Branch:** `agent/airo-tv/shared-channel-import`
**Worktree:** `/Users/udaychauhan/workspace/airo-worktrees/shared-channel-import`

## Press release

Airo users can share a live channel as an Airo link. A recipient who taps the
link opens Airo, reviews the channel and its source host, and can play it once
or save it to a local **Personal channels** list. If Airo is not installed, a
small web landing page explains the link and offers the appropriate install
path instead of returning a 404. Share messages add a small, friendly joke so
the invitation feels like it came from a friend rather than a device log.

## Verified starting point

- The existing Share action in `ChannelInfoBar` copies
  `https://developerscoffee.github.io/airo/iptv?...` with only a channel id.
- As verified on 2026-07-29, that canonical URL returns HTTP 404 and the host
  does not publish Android Digital Asset Links or an Apple App Site
  Association file.
- The existing deep-link resolver can play only a channel already present in
  the recipient's loaded sources. A missing id falls back to Browse with
  “That shared channel is no longer available.”
- The sample
  `https://9xjio.wiseplayout.com/9XM/master.m3u8` is an HLS master manifest,
  not an M3U channel playlist. Its current variants include 1920×1080 at
  4 Mbps, 1280×720, 896×504, 640×360, and 384×216.
- Saving that URL through the existing **Add Playlist Source** flow cannot
  create a channel because the parser expects `#EXTINF` channel entries.
- Airo cannot claim every raw third-party HTTPS `.m3u8` link. Android App
  Links and iOS Universal Links require the owner of the stream host to publish
  an association file. Airo does not control `wiseplayout.com`.

## Product decision

Build a standard **Airo-owned share link + confirmed direct-stream import**
flow. Do not bundle 9XM or any other first-party lineup.

The shared link may carry a public, credential-free stream URL only after the
sender explicitly chooses **Share playable link**. Links containing userinfo,
private/local hosts, or credential-like query parameters are shared as
channel-id-only links and tell the sender that the recipient will need the
same playlist.

This preserves Airo's Play Store BYOC posture: the app is a generic media
player, the user supplies or receives the source, and persistence happens
locally only after confirmation.

## Feature Packet

**Primary owner agent:** Media Intelligence Architect
**Review agents:** Product Manager, Chief Architect, Platform Architect, Chief
Security Officer, Chief QA Officer, Chief UX Officer, Chief Documentation
Officer, Chief Release/DevOps Officer
**Layer:** Mixed
**Impacted modules:** `platform_channels`, `platform_playlist`,
`feature_iptv`, `app` routing/platform manifests, Pages landing/association
deployment
**Verification environments:** host-only tests first; Pixel 9 and iPad for
touch app-link qualification; Fire TV Stick 4K for TV route and D-pad preview

### Critical Agent Gate

**Problem:** A shared channel link currently opens a 404/browser page and can
only resolve when the recipient already has the same channel id. A raw HLS
manifest cannot be stored as a single channel through the playlist importer.

**User / actor:** An Airo viewer sharing a channel and a recipient who is
authorized to play that stream.

**Framework or application layer:** Mixed. URL validation and persisted
personal-channel records are reusable contracts. Share presentation, routing,
confirmation, and playback are application behavior.

**Owning agent:** Media Intelligence Architect.

**Reviewing agents:** As declared above. Security is required because a shared
URL may contain credentials; QA and UX are required because this is a
user-visible import and navigation flow.

**Data created/read/updated/deleted:** A versioned local personal-channel
record; no cloud record. Delete is available from Personal channels. Share
payloads are user-triggered and are never logged or added to analytics.

**Offline behavior:** Previously saved records remain visible. Opening a new
link shows its metadata but playback validation reports offline without
discarding the pending import.

**No-model behavior:** Entirely deterministic; no AI/model dependency.

**Permission behavior:** No new OS permission. The app-link association is a
platform configuration, not a runtime permission.

**Runtime failure behavior:** A failed association opens the web fallback; an
invalid or unreachable stream stays unsaved unless the user explicitly saves
after validation warning. The user can always cancel to Browse.

**Decision:** Ready. The implementation must remain BYOC and must not ship the
9XM URL as a default catalog entry.

### Cross-Agent Contract

**Provider agent:** Platform Architect + Media Intelligence Architect
**Consumer agent:** `feature_iptv` and app host routing
**Interfaces:**

```dart
final class PersonalChannelRepository {
  Future<List<IPTVChannel>> list();
  Future<IPTVChannel?> findByStreamUrl(String streamUrl);
  IPTVChannel buildChannel({
    required String name,
    required String streamUrl,
  });
  Future<IPTVChannel> upsert({
    required String name,
    required String streamUrl,
  });
  Future<void> remove(String channelId);
}

class IptvDeepLinkIntent {
  const IptvDeepLinkIntent({
    required this.channelId,
    this.channelName,
    this.streamUrl,
  });
  final String channelId;
  final String? channelName;
  final Uri? streamUrl;
  bool get canImport;
}
```

**Input shape:** Versioned Airo HTTPS/custom-scheme link with channel id and
optional name + credential-free HTTP(S) stream URL.

**Output shape:** Either an existing-channel intent, a validated import
descriptor, or a typed rejection that is safe to show to the user.

**State changes:** `upsert` writes one local personal-channel record and an
index entry. Duplicate normalized stream URLs update the existing record
instead of creating another channel.

**Errors:** Unsupported version, malformed/oversized values, non-HTTP(S)
scheme, userinfo, private/local host, sensitive query keys, persistence
failure, network timeout, or unsupported media response.

**Permissions:** Internet only. No storage, contacts, or account permission.

**Privacy/redaction:** Reuse `AiroPlaylistUrlPolicy`; extend it with a
share-safe decision that rejects credential-like keys such as `token`,
`auth`, `key`, `signature`, `session`, and signed-expiry parameters. Never log
the full URL or put it in analytics/crash breadcrumbs.

**Persistence:** `platform_playlist` owns a versioned local store. Use one
bounded index key plus one record per stable SHA-256 URL fingerprint, rather
than replacing the user's configured M3U source. Cap Personal channels at 100
records and show a recoverable limit error.

**Versioning/migration:** New additive schema `personal_channel.v1`; no
migration of existing playlist channels. A future schema version must keep
v1 reading or provide an explicit migration.

**Tests required:** Parser/URL-policy unit tests, repository CRUD/dedupe tests,
provider merge tests, import-preview widget tests, route tests, platform
association static checks, web fallback test, and physical app-link
qualification.

### Deterministic Use Cases

#### UC-001: Share a locally available channel

**Actor:** Sender with a channel open in Airo.
**Trigger:** Select Share → **Share playable link**.
**Happy path:** The native share sheet sends an Airo HTTPS link containing a
safe descriptor, the channel name, and one short humorous invitation.
**Alternate path:** **Copy link** remains available.
**Failure path:** A credential-bearing URL produces an id-only link and clear
copy explaining that the recipient needs the same source.
**Data:** No local state change.

#### UC-002: Recipient opens and saves 9XM

**Actor:** Recipient with Airo installed.
**Preconditions:** The received descriptor names `9XM` and uses the sample
HLS master URL.
**Trigger:** Tap the Airo link.
**Happy path:** Airo opens an import preview showing `9XM`, the
`9xjio.wiseplayout.com` host, and **Adaptive stream (up to 1080p)** after
manifest inspection. The user selects **Save & play**. A Personal channels
record is stored and adaptive playback starts.
**Alternate path:** **Play once** starts playback without persistence.
**Failure path:** Timeout or HTTP/media error shows Retry, Save anyway, and
Cancel without auto-saving.
**Data:** One local record is created or updated.

#### UC-003: Open the same channel again

**Actor:** Recipient who already saved the stream.
**Trigger:** Open the same Airo link.
**Happy path:** The preview identifies **Already in Personal channels**;
**Play** is primary and no duplicate is written.
**Data:** At most the display name or `updatedAt` changes.

#### UC-004: Airo is not installed

**Actor:** Recipient in a browser.
**Trigger:** Open the Airo HTTPS link.
**Happy path:** A non-playing landing page explains “Open this channel in
Airo,” offers install/open choices, and does not fetch the stream URL.
**Privacy:** The landing page has no third-party analytics and does not log
the query string.

#### UC-005: Delete a saved channel

**Actor:** User in Personal channels.
**Trigger:** Remove channel and confirm.
**Happy path:** The record disappears from Browse, search, rails, and future
deep-link resolution.
**Failure path:** Persistence failure restores the row and shows a retry.

### Automation Flows

#### AUTO-001: Parse safe and unsafe shared links

**Given:** Safe HTTPS URL, tokenized URL, private-host URL, oversized payload,
unknown version, and id-only v1 fixtures.
**When:** The intent parser runs.
**Then:** Safe v2 becomes an import intent; unsafe v2 is rejected without
echoing secrets; v1 remains backward compatible.
**Environment:** Host-only.

#### AUTO-002: Persist and merge a personal channel

**Given:** Empty local store and existing playlist channels.
**When:** The sample descriptor is upserted twice and
`iptvChannelsProvider` reloads.
**Then:** Exactly one Personal channel is merged, searchable, and preferred
for its exact fingerprint without replacing the user's playlist source.
**Environment:** Host-only.

#### AUTO-003: Confirm before network or persistence

**Given:** An import intent.
**When:** The route builds.
**Then:** No playback and no repository write occurs before Play once or Save
& play. Cancel returns to Browse.
**Environment:** Host-only widget test.

#### AUTO-004: Association and fallback contract

**Given:** Android manifests, iOS entitlements, hosted association fixtures,
and the Pages route.
**When:** Static and browser checks run.
**Then:** Both Android application ids and the iOS application identifier are
declared; `/airo/iptv/` returns 200; the fallback page never embeds or fetches
the stream.
**Environment:** Host-only.

#### AUTO-005: Physical app-link qualification

**Given:** A release-signed candidate and published association files.
**When:** The same Airo link is tapped from Messages/Chrome/Safari.
**Then:** Pixel 9 and iPad open the import preview; Fire TV opens the D-pad
preview or browser fallback according to installed-handler capability.
**Environment:** Pixel 9, iPad Air 4, Fire TV Stick 4K.

## UX contract

1. Share uses the native share sheet, with Copy link as a secondary action.
2. The recipient always sees an import preview for a channel not already
   stored. Receiving a link never auto-saves or auto-plays.
3. Preview content is limited to channel name, source host, detected media
   type/maximum resolution, and the authorization reminder:
   “Only add streams you have permission to watch.”
4. Primary actions are **Save & play**, **Play once**, and **Cancel**.
5. Saved channels appear under **Personal channels** and participate in the
   existing browse/search/favorite/history flows.
6. TV controls use `TvFocusable`, announce validation state, and place focus
   on Save & play only after the descriptor is valid.

### Share-message voice

The default share message is:

> I found the channel. You bring the snacks. 🍿
> Watch {channelName} in Airo:
> {airoLink}

The standard v1 rotation contains three additional generic messages:

> The remote has spoken. 📺 {channelName} is on.
> Open it in Airo: {airoLink}

> No spoilers—just a very watchable link. 👀
> Watch {channelName} in Airo: {airoLink}

> Your group chat now has programming. 😄
> Open {channelName} in Airo: {airoLink}

Message rules:

- Keep the channel name and link literal so the invitation remains useful
  when an app strips rich previews.
- Keep each message under 180 characters before the URL.
- Use one emoji at most and always preserve the meaning without it.
- Avoid jokes about identity, culture, politics, religion, disability, age,
  or a channel's editorial content.
- Do not use humor in consent, authorization, privacy, validation, offline, or
  error copy.
- Reference-only shares use direct copy, not a joke:
  “Open {channelName} in Airo. You’ll need the same playlist: {airoLink}”.
- `ChannelShareMessageComposer` owns the templates and accepts an injected
  selector. Production rotates the safe set; tests select a fixed index so
  snapshots and accessibility assertions never become flaky.
- Templates are localization-ready. If a localized playful template is not
  available, fall back to the clear reference-only sentence.

## App-link and web fallback design

- Keep `https://developerscoffee.github.io/airo/iptv/` as the share origin
  only if the organization Pages root can publish:
  `/.well-known/assetlinks.json` and
  `/.well-known/apple-app-site-association`.
- Android `src/main` and `src/tv` manifests declare verified HTTPS handlers.
  Digital Asset Links list `io.airo.app` and `io.airo.app.tv` with the actual
  release signing certificate fingerprints.
- iOS adds the Associated Domains entitlement and AASA entry for
  `DR4Z2C2LSW.com.developerscoffee.airo`.
- Add a real `/airo/iptv/` landing page. Keep the parser tolerant of the
  legacy path without a trailing slash.
- If the organization root cannot publish association files, move sharing to
  a dedicated Airo-controlled domain. Do not ship an unverified universal
  link and call the browser fallback “complete.”

## Implementation boundaries

- `platform_channels`: share-safe URL policy and typed validation result.
- `platform_playlist`: `PersonalChannelRepository`, versioned persistence,
  fingerprint/dedupe contract.
- `feature_iptv`: link intents, merge provider, import-preview UI, Personal
  channels management, native share action.
- `app`: route composition, Android/iOS app-link configuration.
- `docs`: safe web fallback and external root-domain association deployment
  instructions.
- No new package and no new state-management pattern.
- No changes to playback engine, M3U parsing, or the user's single playlist
  source.

## Non-goals

- Claiming arbitrary third-party `.m3u8` links on Android or iOS.
- Bundling 9XM or any channel as Airo-provided content.
- Uploading personal channels to an Airo service.
- Sharing credentialed, expiring, LAN, or private-host stream URLs.
- Resolving licensing/redistribution rights on the user's behalf.
- Forcing 1080p; the existing player remains adaptive.

## Success metrics

- 100% of qualified Android/iOS Airo links open the installed app in the
  physical-device qualification matrix.
- 0 automatic saves or playback starts from a received link.
- 0 full stream URLs in logs, analytics, or crash reports.
- One saved record per normalized stream URL after repeated imports.
- Web fallback returns 200 and performs zero stream-host requests.
- 100% of generated share messages retain the literal channel name and Airo
  link and stay within the copy-length bound.

## Rollback

- Keep v1 id-only parsing.
- Gate v2 descriptor generation and import preview with
  `AIRO_SHARED_CHANNEL_IMPORT`.
- Disabling the flag returns Share to id-only links while leaving already
  saved Personal channels readable and removable.
- Association files and the web fallback can stay published during rollback.
