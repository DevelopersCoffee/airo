# Provider Reliability Layer Strategy

## Product Signal

The provided Reddit analysis says users do not trust IPTV providers. They trust software that protects them from provider failures.

Recurring problems:

- Provider disappears.
- URL changes.
- Buffering during live events.
- Scams and poor support.
- Confusion about Xtream vs M3U.
- Users cannot tell whether failure is provider, Wi-Fi, ISP, decoder, or app.

The strategic direction is correct: Airo should make providers more replaceable. The current v2 implementation must stay bounded and local.

## V2 Slice

Adopt now:

- Local provider/source capability report.
- Local provider/source health snapshot.
- Likely-cause diagnostics for playback failures.
- Redacted metrics and cache keys.
- Health signals connected to CV-001 playback diagnostics.

This is implemented through CV-012 and CV-001.

## Future Platform

Defer until foundations exist:

- Multi-provider failover.
- Provider replacement migration.
- AI assistant actions.
- Provider identity graph across multiple sources.
- Syncing favorites/history/rules across devices.
- Recording preservation during provider replacement.

Dependencies:

- CV-017 canonical channel identities.
- CV-006 local search.
- CV-015 EPG identity/windowing.
- CV-002 sync if cross-device preservation is required.
- CV-005 AI layer if natural-language actions are required.
- CV-004 DVR if recordings are included.

## Architecture Direction

```text
User BYOC source
  -> Airo source capability report
  -> Airo health snapshot
  -> Playback diagnostics
  -> Smart playlist and canonical channel view
```

Future:

```text
Provider A / Provider B
  -> Source capability reports
  -> Channel identity graph
  -> Migration matcher
  -> Restored favorites/history/EPG/rules
```

## Guardrails

- Do not recommend, rank, or endorse IPTV providers.
- Do not add a provider marketplace.
- Do not auto-failover across providers in v2.
- Do not call provider-specific APIs unless a future provider integration is approved.
- Do not log raw URLs, credentials, local paths, or local IPs.
- Do not claim certainty when metrics are insufficient.
