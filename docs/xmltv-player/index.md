---
layout: landing
permalink: /xmltv-player/
title: "XMLTV Player — Add a Programme Guide to Your Playlist | Airo TV"
description: "Airo TV pairs your M3U/M3U8 playlist with an authorized XMLTV guide for programme data and clearer playback diagnostics. Open source, no bundled EPG."
eyebrow: "XMLTV guide player"
hero_title: "An XMLTV guide, paired with your own playlist."
lede: "Add an authorized XMLTV source next to your M3U/M3U8 playlist and Airo TV uses it for programme data and more specific playback-recovery states — not just a generic error when a stream fails."
primary_cta: "Download Airo TV"
capabilities_title: "What the XMLTV guide is used for"
capabilities:
  - title: Programme data alongside your playlist
    text: Add an authorized XMLTV source and its programme listings attach to the channels in your existing M3U/M3U8 playlist.
    status: available
    status_label: Available
  - title: Bounded, clearer playback diagnostics
    text: With a guide present, playback problems get more specific, bounded recovery states instead of a single generic failure message.
    status: available
    status_label: Available
  - title: Playlist playback stays the foundation
    text: The guide is additive. Without an XMLTV source, playlist playback, search, and favorites work exactly the same.
    status: available
    status_label: Available
  - title: Guide hosting or generation
    text: Airo TV does not host, generate, or edit XMLTV files — it consumes a source URL you already have.
    status: planned
    status_label: Not supported
related_title: "Set it up"
related:
  - title: Add an authorized XMLTV source
    text: Pair a guide URL with your existing playlist.
    url: /tv/guides/#playlist
    icon: calendar
  - title: Don't have a playlist yet?
    text: Start with an M3U or M3U8 source — the guide pairs with it once both are loaded.
    url: /m3u-player/
    icon: list-plus
  - title: Set up Android TV or Google TV
    text: Install, add your sources, browse, search, and play.
    url: /tv/guides/#android-tv
    icon: tv
faq:
  - q: "Does Airo TV come with a built-in programme guide?"
    a: "No. Airo TV ships no channels, playlists, subscriptions, or EPG data of its own. You supply an XMLTV source URL from a provider you are already authorized to use."
  - q: "What does the XMLTV guide actually change in Airo TV?"
    a: "It adds programme data to your existing playlist's channels, and it gives playback failures more specific, bounded recovery states instead of one generic error."
  - q: "Do I need an XMLTV guide to use Airo TV?"
    a: "No. Playlist playback, search, and favorites all work from an M3U/M3U8 source alone. The XMLTV guide is an addition, not a requirement."
  - q: "What format does the XMLTV source need to be in?"
    a: "A standard XMLTV-format URL, the same format used by most EPG providers and other TV player apps."
---

XMLTV is the de facto format for TV programme guides — a plain XML feed
of channel listings and their programme schedules over a time window.
Most IPTV and EPG providers publish one alongside their playlist.

Airo TV treats it as exactly that: an addition to a playlist you've
already loaded, not a separate product. Add the guide's URL and its
programme data attaches to your channels; leave it out and playlist
playback, search, and favorites work the same as they always did.

The other effect of having a guide loaded is less obvious but more
useful day to day — playback failures get bounded, specific
recovery states instead of a flat error, because Airo TV has schedule
context to reason about what should be playing.

If you don't have a playlist loaded yet, [start with your M3U/M3U8
source]({{ '/m3u-player/' | relative_url }}) first; the guide pairs with it once both are in
place.
