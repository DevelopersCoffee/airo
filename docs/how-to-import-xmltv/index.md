---
layout: landing
permalink: /how-to-import-xmltv/
title: "How to Import an XMLTV Guide into Midas Stream"
description: "Add an authorized XMLTV guide to Midas Stream alongside your M3U/M3U8 playlist for programme data and clearer playback diagnostics."
eyebrow: "How-to"
hero_title: "How to import an XMLTV guide."
lede: "An XMLTV guide loads through the same source screen as your playlist — it's a second source, not a separate setup flow."
primary_cta: "Download Midas Stream"
steps_title: "Add the guide"
before_you_start:
  - "You need an XMLTV guide URL from a provider you're authorized to use."
  - "The guide is additive. Load your M3U/M3U8 playlist first if you haven't already — the guide pairs with channels already in your playlist."
steps_subtitle: "Do this"
steps:
  - "Open Midas Stream and choose the playlist or source action — the same screen used for playlists."
  - "Add the XMLTV guide URL as a second source."
  - "Save and wait for the guide to load."
  - "Open a channel and confirm programme data now appears."
structured_data:
  "@context": "https://schema.org"
  "@type": HowTo
  name: How to Import an XMLTV Guide into Midas Stream
  description: Add an authorized XMLTV guide source to Midas Stream alongside an existing playlist.
  step:
    - "@type": HowToStep
      text: Open Midas Stream and choose the playlist or source action — the same screen used for playlists.
    - "@type": HowToStep
      text: Add the XMLTV guide URL as a second source.
    - "@type": HowToStep
      text: Save and wait for the guide to load.
    - "@type": HowToStep
      text: Open a channel and confirm programme data now appears.
related_title: "Related"
related:
  - title: What EPG support actually changes
    text: Programme data and clearer playback diagnostics, explained.
    url: /xmltv-player/
    icon: calendar
  - title: Don't have a playlist yet?
    text: Add your M3U/M3U8 source first.
    url: /how-to-add-m3u-playlist/
    icon: list-plus
  - title: Full device guide
    text: Source setup, remote controls, and troubleshooting.
    url: /midas-stream/guides/#playlist
    icon: book-open
faq:
  - q: "The guide loaded but shows no programme data. What's wrong?"
    a: "Two common causes: confirm the Midas Stream build you're running includes guide support, and confirm the XMLTV feed's channel identifiers actually match the channels in your playlist — a guide with no matching IDs will load but show nothing."
  - q: "Do I need an XMLTV guide to use Midas Stream?"
    a: "No. Playlist playback, search, and favorites all work without one. The guide is an addition, not a requirement."
  - q: "Does Midas Stream provide XMLTV guide data?"
    a: "No. Midas Stream ships no EPG data of its own — you supply a guide URL from a provider you're already authorized to use, the same boundary that applies to playlists."
---

XMLTV import isn't a separate feature hiding in a different menu — it
uses the exact same source screen as adding a playlist, because that's
what it is: another source, just one that carries programme schedules
instead of stream URLs.

If the guide loads but channels show no programme data, the fix is
almost always channel-identifier matching. XMLTV feeds identify channels
by an ID string, and if that string doesn't match what's in your
playlist, Midas Stream has a guide with nothing to attach it to. Check that
your playlist and guide come from a provider that keeps those IDs
consistent between the two files.
