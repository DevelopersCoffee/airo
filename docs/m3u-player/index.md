---
layout: landing
permalink: /m3u-player/
title: "M3U Player for Android TV — Open Any M3U/M3U8 Playlist | Midas Stream"
description: "Open an M3U or M3U8 playlist file or URL on Android TV, Fire TV, or macOS with Midas Stream. Open-source, no bundled channels, no account required."
eyebrow: "M3U / M3U8 player"
hero_title: "You have an M3U file. Midas Stream opens it."
lede: "Point Midas Stream at an M3U or M3U8 playlist URL and it becomes a searchable, TV-first channel grid — no conversion step, no account, no catalog of its own."
primary_cta: "Download Midas Stream"
capabilities_title: "What happens to your M3U file"
capabilities:
  - title: M3U and M3U8 both read directly
    text: Midas Stream parses EXTINF metadata — channel name, group, logo — from standard M3U playlists and M3U8 (HLS) variants without a separate import step.
    status: available
    status_label: Available
  - title: Large playlists stay searchable
    text: Search loaded channels by name instead of scrolling a flat list, which matters once a playlist runs past a few hundred entries.
    status: available
    status_label: Available
  - title: Favorites persist locally
    text: Mark channels as favorites from browse and player flows; the list is stored on-device, not in an account.
    status: available
    status_label: Available
  - title: Survives playlist refreshes
    text: Smart playlists use local rules and canonical channel matching to keep your organization when a provider re-issues the same M3U with reordered or renamed entries.
    status: available
    status_label: Available
  - title: One playlist file, multiple entries
    text: Load more than one authorized M3U source and switch between them; source management stays local to the device.
    status: available
    status_label: Available
  - title: Playlist editing or hosting
    text: Midas Stream does not create, edit, or host M3U files — it only plays a source you already have.
    status: planned
    status_label: Not supported
related_title: "Load your playlist"
related:
  - title: Add an authorized M3U source
    text: Use an M3U or M3U8 URL you are allowed to access.
    url: /midas-stream/guides/#playlist
    icon: list-plus
  - title: Set up Android TV or Google TV
    text: Install, add your playlist, browse, search, and play.
    url: /midas-stream/guides/#android-tv
    icon: tv
  - title: Pair it with an XMLTV guide
    text: Add programme data and clearer playback-recovery states alongside your M3U source.
    url: /xmltv-player/
    icon: calendar
faq:
  - q: "What is the difference between M3U and M3U8?"
    a: "M3U is the original plain-text playlist format. M3U8 is the same format saved as UTF-8, and in practice usually signals an HLS (HTTP Live Streaming) source. Midas Stream reads both without any extra setup."
  - q: "Does Midas Stream provide an M3U playlist?"
    a: "No. Midas Stream ships no channels, playlists, subscriptions, or media catalog. You supply an M3U/M3U8 URL from a source you are already authorized to use."
  - q: "Can I load an M3U file from local storage instead of a URL?"
    a: "Midas Stream supports direct, permission-scoped USB and removable-media browsing on Android TV, in addition to loading a playlist URL."
  - q: "Will Midas Stream keep working if my provider changes the M3U file?"
    a: "Smart playlists use canonical channel matching to preserve your favorites and organization across most reissues of the same source, though a completely restructured file may need re-review."
---

An M3U file is just a text list — a channel name, sometimes a group and a
logo, and a stream URL, repeated per entry. What turns that list into
something usable on a TV is everything *around* the parsing: search that
works with a remote instead of a keyboard, favorites that don't reset
every time the provider re-exports the file, and a grid that doesn't fall
over at a few thousand entries.

That's the part Midas Stream focuses on. Point it at an M3U or M3U8 URL —
`.m3u` and `.m3u8` are read the same way, the extension mostly just hints
at whether the streams behind it are HLS — and it becomes a channel grid
with local search and favorites. Nothing about the playlist is uploaded,
stored remotely, or shared; the source lives only on your device.

If your source also publishes an [XMLTV guide]({{ '/xmltv-player/' | relative_url }}), pairing
the two adds programme data and more specific playback-recovery states
when a stream fails, instead of a generic error.
