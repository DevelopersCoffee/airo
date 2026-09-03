# MultiView v1 host contract

MultiView v1 owns at most four independent playback sessions. The
`platform_player` pool enforces the detected decoder budget, rejects excess
sessions before opening a player, and guarantees a single audible session.
Rapid focus changes are serialized so the latest focused tile owns audio.

Aika Stream renders two sessions in a 1×2 split and three or four sessions in a
stable 2×2 grid. Each session contributes exactly one player view; focus and
tile swaps do not reopen its decoder. D-pad focus routes audio, OK swaps the
focused tile with the featured tile, and the remote menu opens that tile's
audio track, subtitle, and quality/bitrate controls.

Track and quality commands are session-scoped. They cannot change another
tile's engine state. Removing or closing a session mutes and disposes it, and
closing the last session resumes the primary player when it had been paused
for MultiView.

The public packages provide the reusable host and TV interaction contracts.
Product entitlement and Airo Pro presentation remain at the product-capability
and private-overlay boundary.

## Physical qualification

Host tests prove decoder caps, session identity, audio exclusivity, focus,
swap, and independent controls. Release qualification still requires four
live streams on a physical Fire TV, comparing focused-tile dropped frames
against single-stream playback and evaluating RSS against the #779
device-class memory budget. Do not infer those results from widget tests.
