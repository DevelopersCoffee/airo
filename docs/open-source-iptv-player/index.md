---
layout: landing
permalink: /open-source-iptv-player/
title: "Open Source IPTV Player — MIT Licensed | Aika Stream"
description: "Aika Stream is an MIT-licensed, open-source IPTV player for Android TV, Fire TV, and macOS. Public source, public issues, no bundled channels."
eyebrow: "Open-source IPTV player"
hero_title: "Open source, MIT licensed, publicly built."
lede: "Aika Stream's source is public under the MIT licence — the same repository that ships the release also carries every open issue, every pull request, and the roadmap behind them."
primary_cta: "Download Aika Stream"
capabilities_title: "What open source actually gets you here"
capabilities:
  - title: MIT licence
    text: Aika Stream is published under the MIT licence — permissive, with no requirement to open-source anything you build separately.
    status: available
    status_label: Available
  - title: Public source, public history
    text: The full source, commit history, and build workflow that produce the published release APKs are on GitHub.
    status: available
    status_label: Available
  - title: Public issue tracking
    text: Bugs and known limitations are tracked in the open, including the ones this site links to rather than hides.
    status: available
    status_label: Available
  - title: Public roadmap
    text: Planned, in-progress, and deliberately-not-adopted work is visible, not just shipped features.
    status: available
    status_label: Available
  - title: Local-first data
    text: Playlists and app data stay on the device unless you load a remote URL directly.
    status: available
    status_label: Available
  - title: No hidden subscriptions
    text: No mandatory account and no hidden subscription for the Aika Stream player flow.
    status: available
    status_label: Available
related_title: "See it yourself"
related:
  - title: Source repository
    text: Full source, issues, and pull requests on GitHub.
    url: https://github.com/DevelopersCoffee/airo
    icon: github
  - title: MIT licence text
    text: Read the licence in full.
    url: https://github.com/DevelopersCoffee/airo/blob/main/LICENSE
    icon: scroll
  - title: Public roadmap
    text: What's shipped, in progress, planned, and not adopted.
    url: /aika-stream/#roadmap
    icon: map
faq:
  - q: "What licence is Aika Stream published under?"
    a: "The MIT licence — permissive, and it does not require anything you build on top of Airo to also be open source."
  - q: "Can I audit what Aika Stream does with an IPTV playlist before installing it?"
    a: "Yes. The full source that produces the published release builds is public on GitHub, including the release workflow that builds and signs the APKs."
  - q: "Does open source mean Aika Stream includes free IPTV channels?"
    a: "No. Open source describes the licence and the code, not the content. Aika Stream ships no channels, playlists, subscriptions, or media catalog on any platform."
  - q: "Where are bugs and known issues tracked?"
    a: "In the open, on the same GitHub repository as the source — including issues linked directly from this site rather than left undisclosed."
---

"Open source" gets used loosely enough that it's worth being specific.
Aika Stream is published under the [MIT
licence](https://github.com/DevelopersCoffee/airo/blob/main/LICENSE) —
about as permissive as licences get, and it puts no obligation on
anything you build separately. The [full
source](https://github.com/DevelopersCoffee/airo) is public: the app
code, the release workflow that builds and signs the APKs you download,
and the commit history behind all of it.

The part that matters more day to day is what stays public alongside
the code. Bugs are tracked as open issues, not hidden until a patch
ships — this site links directly to a couple of them on the [Fire TV
page]({{ '/iptv-player-for-fire-tv/' | relative_url }}) rather than pretending they don't
exist. The roadmap is public too, including the things marked *not
adopted* rather than only the shipped feature list.

None of that changes what Aika Stream actually plays: your own M3U/M3U8
playlist and, optionally, an XMLTV guide. Open source is about the
licence and the process, not a bundled channel catalog — Aika Stream
doesn't have one of those on any platform.
