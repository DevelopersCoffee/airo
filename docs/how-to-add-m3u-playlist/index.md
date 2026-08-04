---
layout: landing
permalink: /how-to-add-m3u-playlist/
title: "How to Add an M3U Playlist to Airo TV"
description: "Step-by-step: add an authorized M3U or M3U8 playlist to Airo TV, browse channels, and test playback. Open source, no bundled channels."
eyebrow: "How-to"
hero_title: "How to add an M3U playlist to Airo TV."
lede: "The same five steps work on every supported device: add the source, wait for it to load, then search and play."
primary_cta: "Download Airo TV"
steps_title: "Add the source"
before_you_start:
  - "Use an M3U or M3U8 URL supplied by a source you are authorized to access."
  - "Keep private tokens and provider credentials out of screenshots and support posts."
  - "Test with a small known-good playlist first if you're diagnosing a large or unreliable source."
steps_subtitle: "Do this"
steps:
  - "Open Airo TV and choose the playlist or source action."
  - "Enter the authorized playlist URL carefully."
  - "Save the source and wait for channel loading to finish."
  - "Open Live TV, then use Search if the playlist contains many channels."
  - "Select a channel to test playback."
structured_data:
  "@context": "https://schema.org"
  "@type": HowTo
  name: How to Add an M3U Playlist to Airo TV
  description: Add an authorized M3U or M3U8 playlist source to Airo TV and test playback.
  step:
    - "@type": HowToStep
      text: Open Airo TV and choose the playlist or source action.
    - "@type": HowToStep
      text: Enter the authorized playlist URL carefully.
    - "@type": HowToStep
      text: Save the source and wait for channel loading to finish.
    - "@type": HowToStep
      text: Open Live TV, then use Search if the playlist contains many channels.
    - "@type": HowToStep
      text: Select a channel to test playback.
related_title: "Related"
related:
  - title: Full Android TV / Fire TV device guide
    text: Device-specific install steps, remote controls, and troubleshooting.
    url: /tv/guides/#playlist
    icon: book-open
  - title: More about the M3U/M3U8 format
    text: What Airo TV does with the playlist file itself.
    url: /m3u-player/
    icon: list-plus
  - title: A playlist with thousands of channels?
    text: Search, favorites, and smart playlists for large lists.
    url: /how-to-organize-large-channel-lists/
    icon: list-tree
faq:
  - q: "What if the playlist doesn't load?"
    a: "Airo TV can't repair a provider outage, unsupported codec, expired token, or inaccessible stream. Try a second channel from the same source first, to tell a channel problem apart from a playlist problem."
  - q: "Does Airo TV provide an M3U playlist for me to add?"
    a: "No. Airo TV ships no channels, playlists, subscriptions, or media catalog. You supply the URL from a source you're already authorized to use."
  - q: "Can I add more than one playlist?"
    a: "Yes. Load more than one authorized source and switch between them; source management stays local to the device."
  - q: "M3U or M3U8 — does it matter which one I have?"
    a: "No, both are read the same way. M3U8 usually just signals the streams behind it are HLS."
---

Adding a playlist is the same five-step flow across every device Airo TV
supports — the source screen, the URL field, and the load step don't
change between Android TV, Fire TV, or macOS.

The one thing worth doing before you start: if the playlist is large or
you're not sure it's reliable, test with a small known-good one first.
That way, if something doesn't load, you already know it isn't your Airo
TV setup.

Once a playlist loads, [Search]({{ '/how-to-organize-large-channel-lists/' | relative_url }})
is the fastest way to find a channel in anything past a few dozen
entries — scrolling a TV remote through a thousand-channel list is not
where Airo TV wants you to spend your evening.
