---
layout: landing
permalink: /iptv-player/
title: "IPTV Player — Open Source, Bring Your Own Playlist | Midas Stream"
description: "Midas Stream is an open-source IPTV player for Android TV and Fire TV. Load your own M3U/M3U8 playlist and XMLTV guide. No bundled channels, no subscription."
eyebrow: "Open-source IPTV player"
hero_title: "An IPTV player that ships with no channels."
lede: "Midas Stream plays the M3U/M3U8 playlist and XMLTV guide you already have. Nothing is bundled, nothing is sold, and the source is public."
primary_cta: "Download Midas Stream"
capabilities_title: "What Midas Stream does as an IPTV player"
capabilities:
  - title: Playlist playback
    text: User-supplied M3U playlists and M3U8 streams, subject to source and device codec support.
    status: available
    status_label: Available
  - title: Channel search
    text: Search loaded channels by name.
    status: available
    status_label: Available
  - title: Favorites
    text: Mark channels as favorites locally from browse and player flows.
    status: available
    status_label: Available
  - title: XMLTV guide
    text: Add an authorized XMLTV source for programme data and bounded, clearer playback-recovery states.
    status: available
    status_label: Available
  - title: Smart playlists
    text: Local rules and canonical channel matching help preserve a personal view across source refreshes.
    status: available
    status_label: Available
  - title: Recording and cloud playlists
    text: Midas Stream does not record and does not run cloud playlist storage.
    status: planned
    status_label: Not supported
related_title: "Set it up"
related:
  - title: Set up Android TV or Google TV
    text: Install, add an authorized source, browse, search, and play.
    url: /midas-stream/guides/#android-tv
    icon: tv
  - title: Install on Fire TV
    text: Use the compatible APK safely and understand experimental status.
    url: /midas-stream/guides/#fire-tv
    icon: flame
  - title: See the full Midas Stream product page
    text: Devices, capability matrix, and the public roadmap.
    url: /midas-stream/
    icon: arrow-right
faq:
  - q: "Does Midas Stream come with channels or a free trial subscription?"
    a: "No. Midas Stream includes no channels, playlists, subscriptions, or media catalog. You bring an M3U/M3U8 playlist and, optionally, an XMLTV guide from a source you are already authorized to use."
  - q: "Is Midas Stream free and open source?"
    a: "Yes. Midas Stream is published under an open-source licence, and the full source is on GitHub."
  - q: "What devices does Midas Stream support?"
    a: "Android TV and Google TV are the primary supported platforms. Fire TV, phone/tablet, and macOS are available with documented limitations — see the device support table on the Midas Stream product page."
  - q: "Where do I get an M3U playlist or XMLTV guide to use with Midas Stream?"
    a: "Midas Stream does not provide one. Use a playlist or guide URL from a source you already have the rights to access."
---

Most IPTV apps bundle a channel catalog, a subscription, or both. Midas Stream
does neither — it is a player, not a service. You supply an
[M3U or M3U8 playlist]({{ '/midas-stream/guides/#playlist' | relative_url }}) and, if you have one, an
[XMLTV guide]({{ '/midas-stream/#capability-matrix' | relative_url }}), and Midas Stream turns that into a
TV-first channel grid with search and favorites.

That also means Midas Stream can't tell you what to watch, because it has no
idea what's in your playlist until you load it. What it can do is make a
playlist with thousands of entries usable on an actual TV remote: fast
search instead of scrolling, favorites that persist locally, and smart
playlist rules that keep matching channels across source refreshes instead
of losing your organization every time a provider changes their feed.

The project is open source — the whole point of publishing the code is
that you don't have to take "no bundled content" on faith.
