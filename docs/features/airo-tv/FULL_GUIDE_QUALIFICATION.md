# Full guide and reminders qualification

- Issue: #967
- Code review date: 2026-07-27
- Release claim: implementation complete; physical-device qualification pending

## Implemented contract

- Aika Stream queries bounded, paged guide windows and renders virtualized channel
  rows. The lite-receiver current/next snapshot contract is unchanged.
- Native Rust and Dart fallback XMLTV parsing retain optional subtitle,
  description, categories, episode number, icon URL, rating, and
  new/premiere/repeat flags. Required timestamps are normalized to UTC; UI
  renders device-local time.
- Selecting a TV programme opens a remote-focusable detail dialog. Channel
  labels retain direct playback. Details expose Watch now and future-only
  Set/Cancel reminder actions.
- Reminders persist locally, use inexact allow-while-idle notification alarms,
  carry only a stable channel deep link, and have Android scheduled-notification
  and reboot receivers. No network or cloud state is involved.

## Evidence matrix

| Gate | Evidence | Status |
|---|---|---|
| Native rich-field parsing and bound | Rust unit fixtures and generated bridge | Pass |
| Web/fallback rich-field parsing | `core_native` Flutter tests | Pass |
| Windowing, mixed timezone offsets, rich model | `platform_epg` repository tests | Pass |
| Compact current/next compatibility | Existing compact model/snapshot tests | Pass |
| TV programme detail and actions | `feature_iptv` widget tests | Pass |
| Reminder persistence/schedule/cancel/deep link | Feature scheduler and app gateway tests | Pass |
| Android process-death/reboot restoration | Manifest receiver contract present | Host pass; physical reboot pending |
| Fire TV 24-hour grid frame pacing | Requires a supported physical Fire TV-class device and representative multi-day guide | Pending |

The two pending rows are not inferred from host tests. They must be completed
in release-device qualification before a public “smooth on Fire TV” or
“survives reboot” claim is made. Their absence does not weaken the fail-safe
behavior: reminder records remain local and cancellable, and the guide remains
bounded/virtualized.
