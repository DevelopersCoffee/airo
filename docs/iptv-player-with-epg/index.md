---
layout: landing
permalink: /iptv-player-with-epg/
title: "IPTV Player with EPG — Programme Guide Built In | Aika Stream"
description: "Aika Stream supports an EPG (electronic programme guide) via XMLTV, paired with your own M3U/M3U8 playlist. Open source, no bundled guide data."
eyebrow: "IPTV player with EPG"
hero_title: "An IPTV player that supports a real programme guide."
lede: "Aika Stream supports an EPG through XMLTV — add a guide source next to your playlist and get programme data and clearer playback diagnostics, not just a bare channel list."
primary_cta: "Download Aika Stream"
capabilities_title: "EPG support, specifically"
capabilities:
  - title: XMLTV-based guide
    text: Aika Stream reads standard XMLTV feeds, the format most EPG and IPTV providers already publish.
    status: available
    status_label: Available
  - title: Programme data on your channels
    text: Once a guide source is added, programme listings attach to the matching channels in your existing playlist.
    status: available
    status_label: Available
  - title: Guide-aware playback diagnostics
    text: With a guide present, playback failures get more specific, bounded recovery states instead of one generic error message.
    status: available
    status_label: Available
  - title: EPG is optional
    text: Playlist playback, search, and favorites all work without a guide loaded — EPG is an addition, not a requirement.
    status: available
    status_label: Available
  - title: No guide data included
    text: Aika Stream does not publish, host, or bundle EPG/guide data of its own.
    status: planned
    status_label: Not supported
related_title: "Set it up"
related:
  - title: XMLTV setup and format details
    text: What Aika Stream does with the guide feed, and how pairing works.
    url: /xmltv-player/
    icon: calendar
  - title: Don't have a playlist yet?
    text: A guide pairs with an M3U/M3U8 source once both are loaded.
    url: /m3u-player/
    icon: list-plus
  - title: Add an authorized source
    text: Step-by-step setup for playlist and guide sources.
    url: /midas-stream/guides/#playlist
    icon: list-plus
faq:
  - q: "Does an IPTV player with EPG mean it comes with programme data included?"
    a: "No, not for Aika Stream. EPG support means Aika Stream can read a guide feed you provide — it does not publish or bundle programme data of its own."
  - q: "What guide format does Aika Stream's EPG support use?"
    a: "XMLTV, the standard format most EPG and IPTV providers already publish alongside their playlists."
  - q: "Is EPG required to use Aika Stream?"
    a: "No. Playlist playback, search, and favorites work without a guide. The EPG is an addition on top of your existing playlist."
  - q: "What's the actual benefit of adding a guide, beyond seeing programme names?"
    a: "Playback failures get more specific, bounded recovery states when a guide is present, instead of a single generic error."
---

"Does it support EPG" is a fair filter when comparing IPTV players, and
the honest answer for Aika Stream is: yes, through XMLTV, and it's optional.

A guide feed is not a separate product tier or a paid add-on — it's a
second URL you add next to your playlist. Once it's there, programme
listings attach to your channels, and playback failures get more useful,
specific recovery states instead of one generic error message. Skip it
and Aika Stream still works exactly the same for playlist playback, search,
and favorites.

What it isn't: a source of guide data. Aika Stream doesn't publish or bundle
an EPG of its own, the same way it doesn't bundle channels. You bring a
guide feed you're authorized to use, in standard XMLTV format, from
whatever provider you already have.
