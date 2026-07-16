# Airo Public Claim Policy

## Source priority

1. Published release notes and release assets
2. Public feature, distribution, and qualification matrices
3. Closed public issues with release evidence
4. Open public issues and milestones
5. Approved summaries from private Airo TV Pro work

Higher-priority sources override lower-priority sources.

## Claim states

| State | Public meaning | Required evidence |
| --- | --- | --- |
| Available | A customer can use it in a published artifact | Release notes plus artifact |
| Under qualification | Built or packaged, but device/release evidence is incomplete | Qualification source and limitation |
| Private validation | Implemented or tested privately, not publicly released | Maintainer-approved summary only |
| Planned | Accepted public work, not released | Public issue or milestone |
| Deferred | Intentionally postponed | Public decision and reason |
| Not adopted | Explicitly outside the current product direction | Public decision and reason |

## Private overlay disclosure

- Never link to or name private repository paths on the public page.
- Never publish source excerpts, server hosts, credentials, API keys, billing
  rules, entitlement logic, internal architecture, or commercial timing.
- Describe the customer outcome, not the implementation.
- Keep the internal state as `Private validation` until a public release proves
  availability. Customer-facing copy may say `In testing` when the same release
  boundary remains explicit.
- Map a private capability to a public issue when one exists.
- Omit the capability when disclosure approval or a safe public description is
  missing.

## Brand invariants

- Airo is the default master experience, root-page identity, and modular
  super-app umbrella.
- Airo TV is the first focused product and the active modular product for the
  current release line.
- Airo TV Pro is the only advanced TV edition name. It remains `In testing`
  until a public release proves availability.
- Non-TV capabilities remain part of Airo and do not become separate public
  product brands without a new approved brand decision.
- Airo TV provides no channels, playlists, subscriptions, or media catalog.
- Device wording must preserve experimental, partial, deferred, and unsigned
  limitations.
- A roadmap is a direction, not a delivery-date promise.
- Community Voice copy must link to the public work and explain deferrals.

## Screenshot policy

- Prefer current release screenshots generated from authorized fixtures.
- Do not publish third-party broadcast frames or private provider data.
- Do not show tokens, playlist credentials, MAC addresses, device IDs, or
  account details.
- Label visual concepts and private previews so they cannot be mistaken for a
  shipped screen.

## Third-party live demos

- Require explicit maintainer approval for the named source and channel.
- Connect only after a user gesture. Do not autoplay or preload manifests,
  media, advertising, or tracking endpoints.
- Identify the channel, public listing, external host boundary, possible ads,
  regional restrictions, and availability risk before playback.
- Do not proxy, copy, cache, repackage, or rebroadcast third-party media.
- Keep the application boundary explicit: a website sample does not mean the
  Airo TV app bundles or provides channels.
- Provide accessible loading, playing, unsupported, unavailable, and fatal
  error states, and destroy the session when the visitor leaves the page.
- Attempt at most one automatic media or network recovery within a finite
  deadline, then expose an enabled manual retry instead of looping silently.
- Revalidate source availability, browser CORS behavior, and disclosure copy
  during every release-branding refresh.
