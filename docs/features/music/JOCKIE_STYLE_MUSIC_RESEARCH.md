# Jockie-Style Music Playback Research

Date: 2026-06-22

## Executive Summary

Jockie Music's Discord experience is not a direct blueprint for Aero unless Aero is also building a Discord bot. Jockie-style bots join Discord voice channels, decode/fetch audio in a server-side worker, encode it to Discord-compatible Opus, and send encrypted RTP packets to Discord voice servers.

For Aero, the right equivalent is different: a persistent in-app music session with a queue, provider search, provider playback adapters, background audio controls, and a mini player that survives tab changes. The current app already has the early shape for this (`MusicService`, `JustAudioMusicService`, `/live/music`, `MiniPlayer`, `GlobalAudioService`), but it still relies on sample direct URLs and lacks a legal provider resolver.

The biggest product/legal constraint: Spotify, Apple Music, YouTube, Deezer, Tidal, SoundCloud, Bandcamp, and Mixcloud do not all give the same playback rights. In particular, Spotify/Apple/Tidal links generally should be handled by official SDK playback in the user's authenticated client, not by extracting raw audio and rebroadcasting it. YouTube audio-only/background playback is explicitly not a safe path under YouTube API policy.

## What Jockie-Style Discord Bots Do

Discord voice is a separate voice gateway plus UDP media connection. Discord expects voice data encoded as Opus, stereo, 48 kHz, carried in RTP and encrypted before transport.

Typical bot flow:

1. User issues a command such as `play <query-or-url>`.
2. Bot confirms the user's voice channel and joins through Discord's bot API.
3. A resolver identifies the source: direct HTTP, SoundCloud, YouTube, Spotify URL, Apple Music URL, radio URL, etc.
4. A playback worker fetches or resolves a playable media stream.
5. Audio is decoded/transcoded if needed, usually with FFmpeg/Lavaplayer/Lavalink.
6. Bot sends Opus frames to Discord voice.
7. Queue, skip, pause, shuffle, permissions, and multi-instance routing are handled by the bot backend.

Jockie's public listing claims support for Spotify, Tidal, Deezer, Apple Music, direct HTTP, Discord attachments, radio, SoundCloud, Vimeo, Bandcamp, and Mixcloud. Its site also describes the "one server, multiple bots, one prefix" model: up to four bot identities share settings and the next available bot joins another voice channel.

Important distinction: support for a provider URL does not necessarily mean the bot streams audio from that provider. Lavalink/LavaSrc-style systems commonly "mirror" metadata from Spotify/Apple/Tidal to a different direct playback source. LavaSrc's own docs describe Spotify, Apple Music, and Tidal as mirror sources, while Deezer/Yandex/VK/Qobuz/JioSaavn can be direct depending on configuration and credentials.

## Relevant Bot Stack Options

If Aero ever builds an actual Discord bot:

- `@discordjs/voice`: Node.js implementation of Discord voice, with audio players/resources, Opus, encryption, FFmpeg support, and horizontal-scaling support.
- Lavalink: Java audio node used by many Discord bots. The bot sends voice state to Lavalink; Lavalink resolves tracks and streams to Discord. It is designed for multiple concurrent streams and sharding.
- Lavalink plugins:
  - `lavalink-devs/youtube-source`: YouTube/Lavaplayer source manager using multiple InnerTube clients. Technically common, legally sensitive.
  - `topi314/LavaSrc`: additional sources for Spotify, Apple Music, Deezer, Tidal, Qobuz, JioSaavn, VK, Yandex, etc. It distinguishes mirror playback from direct playback.

For Aero's Flutter app, we should not put Lavalink in the app. Use Flutter/native playback and provider SDKs. A server can still help with search, OAuth token exchange, provider metadata normalization, and licensed direct-stream catalogs.

## Provider Reality Check

### Spotify

Use cases:

- Metadata/search/playlists: Spotify Web API.
- Actual playback: Spotify Web Playback SDK on web, or native SDK/Spotify app integration on mobile where supported.
- Requirement: Premium subscription for music streaming through Spotify Platform.

Constraints:

- Spotify policy says music streaming through the Spotify Platform is only for Premium subscribers.
- Spotify policy restricts commercial use of streaming SDAs and public/business broadcast use.
- Spotify preview clips cannot become a standalone music product.
- Spotify is not a raw audio CDN for Aero; do not extract, cache, rebroadcast, or transcode Spotify content.

Recommended Aero integration:

- Add Spotify OAuth.
- Use Spotify Web API for search and metadata.
- For full playback, control Spotify's official player/session where allowed.
- In the unified queue, Spotify tracks should be `providerPlayback` items, not `directStreamUrl` items.

### YouTube / YouTube Music

Use cases:

- Search and metadata: YouTube Data API.
- Playback: visible YouTube embedded/native player.

Constraints:

- YouTube API policy prohibits separating/isolation/modifying audio or video components.
- It also prohibits background-player features where the player is not displayed on the current page/tab/screen.
- It prohibits using non-YouTube-API technology to access YouTube audiovisual content when working with YouTube API Services.

Recommended Aero integration:

- Do not implement YouTube as audio-only background music.
- If YouTube support is required, use a visible YouTube player mode, not the global background music queue.
- Do not use `yt-dlp`, InnerTube stream extraction, or Lavalink YouTube source in a commercial Aero app without specific legal review and licenses.

### Apple Music

Use cases:

- Metadata/catalog: Apple Music API.
- Playback: MusicKit for Apple platforms, Android, and web.

Constraints:

- Requires Apple developer tokens, media identifier/private key, user authorization, and active Apple Music subscription for full playback.
- Playback is through MusicKit, not raw downloadable audio.

Recommended Aero integration:

- Good candidate for official in-app playback, especially iOS.
- Build a `MusicProviderAdapter` backed by MusicKit state and queue control.

### Deezer

Use cases:

- Metadata and 30-second previews through public API/SDK.
- Full streaming only where Deezer SDK/account rights permit or via commercial agreement.

Constraints:

- Deezer FAQ says website/iOS JavaScript SDK streaming has only 30-second previews.
- Whitelisting to avoid API limitations is not possible unless there is a commercial agreement.

Recommended Aero integration:

- Use Deezer previews for discovery only, or pursue a commercial agreement.
- Do not treat Deezer public API as a full-track music source by default.

### Tidal

Use cases:

- TIDAL API/SDK for metadata and official playback integrations.

Constraints:

- Use the official SDK/player path. Treat any mirror/direct extraction plugin as server-side bot technology with legal risk unless licensed.

Recommended Aero integration:

- Consider later if we need high-fidelity subscriber playback and can implement the SDK cleanly.

### SoundCloud

Use cases:

- SoundCloud API can resolve track resources and expose stream/transcoding URLs for playable tracks.
- Public tracks can be streamed; private tracks need authorization/secret token.

Constraints:

- Must comply with SoundCloud API terms, attribution, and creator rights.
- Not every track is streamable or licensed for arbitrary app use.

Recommended Aero integration:

- Good first third-party provider candidate for direct-stream behavior if API access and terms are acceptable.
- Implement as `directStreamUrl` only when API says the track is streamable.

### Bandcamp

Use cases:

- Official API is mainly for labels/merch fulfillment partners and requires approval.

Constraints:

- No general public full-catalog streaming API for consumer playback.

Recommended Aero integration:

- Do not prioritize unless we have partner/API access or are linking out.

### Mixcloud

Use cases:

- Metadata and embeddable widgets.

Constraints:

- Mixcloud docs state audio streams are not available through its API because usage must be tracked for royalties and product economics.

Recommended Aero integration:

- Use visible embedded widget or link-out only.
- Do not try to direct-stream Mixcloud audio.

### Direct HTTP, Radio, Licensed Catalogs

Use cases:

- Direct MP3/AAC/HLS streams.
- Internet radio streams.
- Airo-hosted licensed music.
- Creative Commons/royalty-free catalog providers.

Constraints:

- Direct technical access does not imply legal playback rights.
- Need terms/license validation for each source.

Recommended Aero integration:

- This is the safest MVP route.
- Replace sample MP3s with:
  - owned/licensed assets,
  - royalty-free catalog,
  - properly licensed radio streams,
  - creator-uploaded content with explicit rights.

## Recommended Aero Architecture

### Product Behavior

- User can search or paste a URL.
- Aero resolves the query to tracks from enabled providers.
- User starts playback.
- Music continues while the user switches to games, agent chat, IPTV, etc.
- SFX/voice/video can duck or pause music through `AudioContextManager`.
- A persistent `MiniPlayer` shows state globally.

### Core Interfaces

Add provider-level abstractions instead of putting provider logic into `JustAudioMusicService`.

```dart
enum MusicPlaybackKind {
  directStream,
  providerSdk,
  embeddedVisiblePlayer,
  previewOnly,
  unsupported,
}

class ResolvedTrack {
  final MusicTrack metadata;
  final String provider;
  final MusicPlaybackKind playbackKind;
  final Uri? streamUri;
  final Uri? canonicalUri;
  final Map<String, Object?> providerPayload;
}

abstract interface class MusicProviderAdapter {
  String get id;
  Future<List<ResolvedTrack>> search(String query);
  Future<ResolvedTrack?> resolve(Uri uri);
  Future<bool> canPlay(ResolvedTrack track);
}
```

Playback services:

- `DirectStreamPlaybackEngine`: current `just_audio` path for licensed URLs, HLS, MP3/AAC, SoundCloud stream URLs where allowed.
- `SpotifyPlaybackEngine`: official Spotify playback/session control; no raw URL.
- `AppleMusicPlaybackEngine`: MusicKit wrapper.
- `YouTubeVisiblePlaybackEngine`: visible embedded player only; excluded from background queue.
- `PreviewPlaybackEngine`: 30-second preview playback for discovery.

Queue model:

- Store normalized metadata and provider payload.
- Queue items should declare whether they can run in background.
- If a queue contains provider SDK tracks, the active engine owns playback and state sync.

### Backend Services

Minimum backend:

- OAuth token exchange and refresh for Spotify/Apple/Tidal/SoundCloud where needed.
- Provider search proxy with caching of metadata only.
- License registry for direct/radio streams.
- Abuse/rate-limit control.
- Analytics for playback errors, provider failures, and unsupported tracks.

Do not cache or proxy full music audio unless we own the content or have explicit rights.

## Current Aero Code Notes

Relevant files:

- `app/lib/features/music/domain/services/music_service.dart`
- `app/lib/features/music/domain/services/just_audio_music_service.dart`
- `app/lib/features/music/domain/services/music_track_service.dart`
- `app/lib/features/music/application/providers/music_provider.dart`
- `app/lib/features/music/application/providers/music_tracks_provider.dart`
- `app/lib/features/music/presentation/screens/music_screen.dart`
- `app/lib/features/music/presentation/widgets/mini_player.dart`
- `app/lib/core/audio/global_audio_service.dart`
- `app/lib/core/audio/AUDIO_ARCHITECTURE_WIP.md`

Likely immediate problems:

- `MusicTrackService.getSampleTracks()` uses a suspicious third-party download URL for multiple famous songs. This is both unreliable and legally unsafe.
- `JustAudioMusicService.getStateStream()` only yields from `playerStateStream`; if `just_audio` does not emit an initial event in a given platform/build, the UI can stay in loading. It should yield an initial `MusicPlayerState` before subscribing.
- There are two music service concepts: feature-level `MusicService` and core-level `GlobalAudioService`. They should be unified or clearly separated.
- The UI title says "Spotify Top 20 India", but the app is not integrated with Spotify and does not have Spotify playback rights.

## Implementation Plan

### Phase 0: Stabilize Current Music Screen

- Replace unsafe sample URLs with owned/licensed sample tracks or no-audio metadata.
- Make `getStateStream()` emit an initial idle state.
- Add error state for failed stream load instead of silently skipping forever.
- Show provider/source labels and "preview/direct/radio" badges.

### Phase 1: Direct Licensed Playback

- Build `MusicProviderAdapter` and `ResolvedTrack`.
- Add a direct licensed catalog provider.
- Support HLS/MP3/AAC streams through `just_audio`.
- Persist queue and mini-player state.
- Integrate `audio_service` for Android/iOS background controls.

### Phase 2: SoundCloud and Radio

- Add SoundCloud search/resolve/playback only for streamable tracks.
- Add curated radio streams with license metadata.
- Add rate limiting and provider error telemetry.

### Phase 3: Spotify/Apple Official SDKs

- Spotify: OAuth + Web API metadata + official playback SDK/session control.
- Apple Music: MusicKit catalog/search/playback.
- Mark these as provider-SDK playback, not direct streams.

### Phase 4: Discord Bot Only If Needed

- Build a separate service, not inside Flutter:
  - Node.js/TypeScript bot with Discord app token.
  - `@discordjs/voice` or Lavalink cluster.
  - Shared queue service and multi-bot routing if we need multiple voice channels.
- Only stream audio sources that Aero has rights to rebroadcast into Discord.

## Recommendation

For Aero, do not clone Jockie's extraction-style behavior. Build the user-facing experience Jockie provides: search, queue, persistent playback, mini-player, and activity switching. Use official provider SDKs for subscription services and licensed direct streams for background playback.

The MVP should be:

1. Fix current loading/sample-track reliability.
2. Ship licensed direct-stream playback with queue and mini-player.
3. Add SoundCloud/radio where terms permit.
4. Add Spotify/Apple as official user-authenticated playback integrations.
5. Keep YouTube out of the background audio queue.

## Sources

- Discord Voice docs: https://docs.discord.com/developers/topics/voice-connections
- discord.js voice docs: https://discord.js.org/docs/packages/voice/main
- discord.js audio resources guide: https://discordjs.guide/voice/audio-resources
- Lavalink REST docs: https://lavalink.dev/api/rest
- Lavalink plugins docs: https://lavalink.dev/plugins
- LavaSrc docs: https://github.com/topi314/LavaSrc
- Lavalink YouTube source: https://github.com/lavalink-devs/youtube-source
- Jockie Music site: https://www.jockiemusic.com/
- Jockie Music bot listing: https://discord.bots.gg/bots/411916947773587456
- Spotify Developer Policy: https://developer.spotify.com/policy
- Spotify Web Playback SDK: https://developer.spotify.com/documentation/web-playback-sdk
- YouTube API Developer Policies: https://developers.google.com/youtube/terms/developer-policies
- Apple Music / MusicKit: https://developer.apple.com/musickit/
- Deezer developer FAQ: https://support.deezer.com/hc/en-gb/articles/360011538897-Deezer-FAQs-For-Developers
- SoundCloud API guide: https://developers.soundcloud.com/docs/api/guide
- Bandcamp API: https://bandcamp.com/developer
- Mixcloud API docs: https://www.mixcloud.com/developers/
