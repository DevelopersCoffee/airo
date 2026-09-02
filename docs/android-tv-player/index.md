---
layout: landing
permalink: /android-tv-player/
title: "Android TV Player Built for the Remote — Midas Stream"
description: "Midas Stream is a leanback-first Android TV and Google TV player: D-pad navigation, title-safe layout, and direct-install or Play Store setup. Open source."
eyebrow: "Android TV / Google TV player"
hero_title: "Built for the remote, not ported to it."
lede: "Midas Stream is a leanback-first player: D-pad navigation, focus that survives playback, and layout that respects the TV-safe frame — on Android TV and Google TV, direct-install or through the Play Store."
primary_cta: "Download Midas Stream"
capabilities_title: "What the Android TV build does"
capabilities:
  - title: Leanback D-pad navigation
    text: Directional focus across search, browse, and playback, tuned specifically for a TV remote rather than a touchscreen layout stretched to fit.
    status: available
    status_label: Available
  - title: Direct-install APK or Play Store AAB
    text: Both a direct-install release APK and a Play Store AAB are published for the Android TV / Google TV profile.
    status: available
    status_label: Available
  - title: Direct USB and removable-media browsing
    text: Permission-scoped browsing of local files on connected USB or removable media, without converting them into a playlist first.
    status: available
    status_label: Available
  - title: Google Cast support
    text: Send playback to a Chromecast receiver, subject to local network discovery and receiver reachability.
    status: available
    status_label: Supported path
  - title: Fire TV
    text: A compatible APK path exists; Fire TV remains a separate, experimental qualification track rather than a fully supported target.
    status: qualifying
    status_label: Experimental
related_title: "Set it up"
related:
  - title: Set up Android TV or Google TV
    text: Install, add a source, browse, search, and play.
    url: /midas-stream/guides/#android-tv
    icon: tv
  - title: Bring an M3U/M3U8 playlist
    text: Load a playlist source once Midas Stream is installed.
    url: /m3u-player/
    icon: list-plus
  - title: Install on Fire TV instead
    text: Use the compatible APK path and understand the experimental status.
    url: /midas-stream/guides/#fire-tv
    icon: flame
faq:
  - q: "Is Midas Stream available on the Google Play Store?"
    a: "Yes, a Play Store AAB is published for the Android TV / Google TV profile alongside a direct-install APK."
  - q: "Does Midas Stream work with a standard Android TV remote?"
    a: "Yes. Navigation is built leanback-first for D-pad input, including focus that holds correctly through playback and returns to the right place afterward."
  - q: "Can Midas Stream play local files from a USB drive on Android TV?"
    a: "Yes. Midas Stream supports direct, permission-scoped browsing of USB and removable media on Android TV, separate from loading a playlist URL."
  - q: "Is this the same app as the Fire TV version?"
    a: "It's the same Android TV build, but Fire TV is tracked as a separate, experimental qualification path rather than a fully supported target — see the Fire TV install guide for current status."
---

Most "Android TV" apps are a phone layout with bigger buttons. The tell
is always the remote: focus jumps to the wrong element, search wants a
keyboard, or a full-screen player forgets where you were when you back
out of it.

Midas Stream is built the other way — leanback first. Every screen is
designed for directional D-pad navigation from the start, including the
parts that are easy to get wrong: focus that survives returning from
playback, layout that stays inside the TV-safe frame instead of
clipping at the edges on real hardware, and search and settings that
stay reachable no matter how the browse grid is arranged.

It installs the way an Android TV app should — a direct APK for
sideloading, or a Play Store AAB for Google TV devices — and once it's
running, what you do with it is [load your own M3U/M3U8
playlist]({{ '/m3u-player/' | relative_url }}) or browse local files directly from a
connected USB drive. Either way, the point of this page is the
platform experience underneath: Midas Stream was written for a couch and a
remote, not adapted to one.
