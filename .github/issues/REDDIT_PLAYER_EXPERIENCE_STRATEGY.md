# Reddit Player Experience Strategy Notes

## Product Signal

The provided Reddit analysis is more useful for product direction than for provider selection. Users are not asking for Airo to find an IPTV provider. They are asking for a better way to survive messy, unreliable provider feeds.

Recurring user needs:

- Remove channel clutter.
- Keep English or region-specific channels.
- Hide VOD/radio/adult/shopping groups.
- Build a small cable-TV-like package from a huge playlist.
- Understand whether buffering is the provider, network, ISP, decoder, or app.
- Treat provider feeds as replaceable sources rather than durable user identity.
- Keep favorites, history, guide layout, and settings stable when providers change.
- Make the player experience consistent regardless of provider.

## Airo V2 Decision

Adopt a bounded local slice now:

- Smart playlist rule model.
- Canonical channel/alias model.
- Local "My TV" package view.
- Deterministic filters and diagnostics.
- Provider/source capability report.
- Local health snapshot and likely-cause diagnostics.

Defer higher-level intelligence:

- AI setup commands.
- Provider replacement/migration.
- Multi-provider automatic failover.
- Cloud sync of rules.
- Provider marketplace or scoring.

## Why This Matters

Large playlist performance is necessary but not enough. A user does not want to scroll 30,000 channels quickly; they want to avoid seeing 29,940 irrelevant channels at all.

The strategic product move is:

```text
Raw provider feed
  -> Airo normalization
  -> Airo capability and health report
  -> User package rules
  -> Consistent player experience
```

That makes the provider replaceable without making Airo a provider.

## Mapped Issues

- Current v2: `community-voice-17-smart-playlists-normalization.md`
- Current v2 provider health: `community-voice-12-smart-proxy-cache.md`
- Current v2 playback diagnostics: `community-voice-01-self-healing-playback.md`
- Future AI rule setup: `community-voice-05-ai-media-layer.md`
- Future provider/device migration: `community-voice-03-device-migration.md`
- Related search/indexing: `community-voice-06-universal-search.md`
- Related large playlist foundation: `community-voice-10-massive-playlist-engine.md`

## Guardrails

- Do not bundle channel lists or presets.
- Do not recommend IPTV providers.
- Do not rank public providers or imply endorsement.
- Do not automatically switch to another provider in v2.
- Do not auto-fetch external metadata.
- Do not sync playlist rules until account/privacy design is accepted.
- Do not use an SLM to mutate rules without showing the rule draft and deterministic explanation.
