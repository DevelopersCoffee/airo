---
layout: landing
permalink: /how-to-use-iptv-legally/
title: "How to Use IPTV Legally — What Makes a Source Authorized"
description: "What makes an IPTV source authorized, what Aika Stream does and does not provide, and why the app ships no channel catalog. A trust page, not a disclaimer wall."
eyebrow: "How-to"
hero_title: "How to use IPTV legally."
lede: "The short version: only load a playlist or guide from a source you already have the right to access. Everything below explains why Aika Stream is built around that line instead of around a catalog."
primary_cta: "Download Aika Stream"
capabilities_title: "What makes a source authorized"
capabilities:
  - title: You have a subscription or licence for it
    text: A paid IPTV service, a broadcaster's own stream, or a service you're a legitimate customer of.
    status: available
    status_label: Authorized
  - title: It's content you or your organization own or licence
    text: A personal media server, a workplace's own broadcast feed, or anything you have explicit rights to distribute to yourself.
    status: available
    status_label: Authorized
  - title: It's public or permissively licensed
    text: Public-domain or openly licensed streams, published as such by their source.
    status: available
    status_label: Authorized
  - title: A playlist someone shared without knowing its provenance
    text: If you can't say where a stream actually comes from or whether the person sharing it had the right to, that's the case to be careful about.
    status: qualifying
    status_label: Verify first
related_title: "Related"
related:
  - title: What Aika Stream actually ships
    text: The full product page and content boundary.
    url: /aika-stream/
    icon: tv
  - title: Add an authorized playlist
    text: Once you have one, here's how.
    url: /how-to-add-m3u-playlist/
    icon: list-plus
  - title: Privacy policy
    text: What Aika Stream does and doesn't collect.
    url: /legal/privacy-policy/
    icon: shield
faq:
  - q: "Does Aika Stream provide IPTV channels or streams?"
    a: "No. Aika Stream ships no channels, playlists, subscriptions, or media catalog on any platform. It only plays M3U/M3U8 and XMLTV sources you supply yourself."
  - q: "Why doesn't Aika Stream include any channels at all?"
    a: "Because it's a player, not a service. Shipping a catalog would mean Aika Stream — or whoever built it — is making a claim about the right to distribute that content. Not shipping one keeps that question entirely with the source you choose to load."
  - q: "Is it legal to use Aika Stream?"
    a: "Aika Stream itself is open-source software with no content of its own — using it is no different from using any other media player. What matters is whether the specific playlist or stream you load is one you're authorized to access, which is true of any IPTV player, not something specific to Aika Stream."
  - q: "How do I know if a playlist I found online is authorized?"
    a: "If you can't identify who operates the stream and whether they have the right to distribute it, treat that as a reason to look for the source directly — a licensed service, a broadcaster's own feed, or something clearly public — rather than a playlist of unknown origin."
---

Most "is IPTV legal" pages either dodge the question with a legal
disclaimer, or quietly point you toward the thing they're supposedly
warning you about. Neither is useful, so here's the actual distinction:
**IPTV is a delivery method, not a content source.** The M3U/M3U8 and
XMLTV formats Aika Stream reads are used by legitimate services and pirated
ones alike — the format tells you nothing about whether a given stream
is authorized.

What tells you that is provenance. A playlist from a service you pay
for, a broadcaster's own published feed, your own media server, or
something openly licensed — all fine, in the same way any media player
playing those sources would be fine. A playlist someone forwarded you
with no clear origin, promising every channel and sports package that
normally costs money, is the case worth being skeptical of — not
because of anything about the M3U format, but because of what it
usually means when a stream that should require a paid licence is being
handed around for free.

Aika Stream's own answer to this is structural, not just a policy: it ships
no catalog at all. There is nothing to browse until you add a source,
which means the authorization question is entirely yours to answer —
Aika Stream isn't making that call on your behalf by pre-loading anything.
