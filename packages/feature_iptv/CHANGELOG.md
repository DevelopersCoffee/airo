## 0.0.1

- Added the offline Intent Engine v1 adapter, contract validation, confidence
  fallback, and local playlist/EPG/history execution boundary.
- Added the responsive Airo TV Explorer shell with persistent channel filters,
  saved filters, hotbar shortcuts, and resume-last-channel behavior.
- Added Ways to Watch for fitted, fullscreen, supported floating-window, and
  Cast playback.
- Added persistent Explorer row controls, real engine-reported playback stats,
  contextual help, and in-app release notes.
- Added channel-tile multiview controls with single, 1x2 split, and bounded
  2x2 layouts. Multiview follows D-pad focus for audio, swaps live sessions
  without reopening decoders, and provides independent per-tile
  track/subtitle/quality selection.
- Limited concurrent multiview decoders to two on web and mobile and four on
  desktop, with a hard ceiling of four and clear capacity feedback.
- Changed channel sharing to copy versioned Airo TV deep links that can restore
  the active Explorer filters and tune the channel without exposing stream
  URLs.
- Added video-frame sharing from a capture boundary that excludes Explorer
  chrome. The host opens the platform share surface where image sharing is
  available.
