---
layout: landing
permalink: /iptv-player-for-fire-tv/
title: "IPTV Player for Fire TV — Fire OS vs Vega OS | Aika Stream"
description: "Vega OS Fire TV sticks cannot sideload Android apps. Aika Stream's Fire OS build is not on the Amazon Appstore yet. Use Google Play on Android TV or Google TV."
eyebrow: "IPTV player for Fire TV"
hero_title: "Fire TV support, stated honestly."
lede: "Vega OS sticks cannot install Android apps. On Fire OS, a separate Aika Stream build exists and is not listed on the Amazon Appstore yet. Android TV and Google TV on Google Play are the supported path today."
primary_cta: "Download Aika Stream"
steps_title: "Playback buffers"
steps_subtitle: "About a minute"
steps:
  - "Clear the app cache only. Leave app data alone — clearing data removes the playlist saved on the device."
  - "Free storage on the device."
  - "If the player offers a decoder choice, try the hardware decoder."
  - "Restart the device."
  - "Open the same playlist on another device. If it buffers there too, the source or the network is the limit."
capabilities_title: "Fire TV status, as published"
capabilities:
  - title: Vega OS
    text: Fire TV Stick 4K Select and other Vega OS models cannot install Android APKs, including through Downloader. Aika Stream has no Vega build.
    status: planned
    status_label: Unsupported
  - title: Fire OS build
    text: A Fire OS build sits beside the Google Play Android TV build. It is not submitted to the Amazon Appstore yet, so there is no store install to use.
    status: qualifying
    status_label: Not listed yet
  - title: Playlist playback
    text: M3U/M3U8 playlist loading, search, and favorites work the same as on Android TV once installed.
    status: available
    status_label: Available
  - title: "Known issue: back navigation"
    text: The BACK key is intermittently swallowed on the channel-browse grid after returning from playback (tracked as #1430).
    status: qualifying
    status_label: Open issue
  - title: "Known issue: log noise"
    text: Live playback emits frequent vendor property-denial messages in the device log during normal operation (tracked as #1243). Cosmetic — it does not affect playback.
    status: qualifying
    status_label: Open issue
  - title: Dedicated Fire TV qualification
    text: Full, dedicated Fire TV qualification — beyond the compatible APK path — remains outstanding.
    status: planned
    status_label: Not yet qualified
related_title: "Set it up"
related:
  - title: Fire TV install guide
    text: See the Fire OS device guide. Vega OS sticks are not an install target.
    url: /airo-tv/guides/#fire-tv
    icon: flame
  - title: Android TV or Google TV
    text: The supported install for Vega OS owners, from Google Play.
    url: /iptv-player-for-android-tv/
    icon: tv
  - title: "Track issue #1430: BACK key on browse grid"
    text: Current status of the back-navigation issue.
    url: https://github.com/DevelopersCoffee/airo/issues/1430
    icon: bug
  - title: "Track issue #1243: playback log noise"
    text: Current status of the vendor log-message issue.
    url: https://github.com/DevelopersCoffee/airo/issues/1243
    icon: bug
faq:
  - q: "Can I sideload Aika Stream on a Vega OS Fire TV Stick?"
    a: "No. Vega OS, including the Fire TV Stick 4K Select, does not install Android APKs and does not run Downloader installs. For your own playlist, install Aika Stream from Google Play on a Google TV or Android TV device. Package name com.developerscoffee.tv.midas."
  - q: "Is a Downloader code a safe way to install a player?"
    a: "No. Do not install a player from a code or APK someone sends you. Check the store listing and the package name. Never grant a media app Accessibility or SMS permission."
  - q: "Does clearing the cache fix Fire TV buffering?"
    a: "Clear cache only, then free storage, try the hardware decoder, restart, and test the same playlist on another device. Clearing data removes the playlist saved on the device. Cache is not the usual cause when the stream buffers on a second device too."
  - q: "Is Aika Stream fully supported on Fire TV?"
    a: "No. The Fire OS build is not on the Amazon Appstore yet, and Vega OS cannot install it at all. Android TV and Google TV from Google Play are the supported path."
  - q: "What actually goes wrong on Fire TV right now?"
    a: "Two known issues are open: the BACK key is intermittently swallowed on the channel-browse grid after returning from playback, and live playback writes frequent vendor log messages that are cosmetic and don't affect playback."
  - q: "Should I still try Aika Stream on my Fire TV?"
    a: "On Vega OS, no. That stick cannot install the app. On Fire OS, use the official release on this page, not a Downloader code or an APK from a message. The Amazon Appstore listing is not live yet. Android TV and Google TV from Google Play are the qualified path."
  - q: "Does Aika Stream include IPTV channels on Fire TV?"
    a: "No. Aika Stream ships no channels, playlists, subscriptions, or media catalog on any platform, including Fire TV."
---

Check Settings, My Fire TV, About. If the software version starts with 1
or 2, the stick is on Vega OS. Vega OS does not install Android APKs, and
Downloader cannot put a player on it. Aika Stream has no Vega build. Use
[Aika Stream on Google Play](https://play.google.com/store/apps/details?id=com.developerscoffee.tv.midas)
on a Google TV or Android TV device. The package name is
`com.developerscoffee.tv.midas`.

Fire OS is the older Android-based system. A separate Fire OS build of
Aika Stream now exists beside the Play build, and it is not on the Amazon
Appstore yet. Until that listing is live, do not install a player from a
Downloader code or an APK someone messages you. Confirm the Play listing
and the package name, and never give a media app Accessibility or SMS
permission.

If a stream buffers, clear the app cache only. Clearing data wipes the
playlist stored on the device. Then free storage, try the hardware
decoder, restart, and open the same playlist on another device.

Two Fire OS issues stay open on the compatible path. The BACK key is
intermittently swallowed on the channel-browse grid right after you
return from playback. Live playback also writes vendor property-denial
messages to the device log; that noise does not change playback.

Android TV and Google TV remain the qualified target, and the same
playlist works there without changes.
