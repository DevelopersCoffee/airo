---
layout: default
title: Privacy Policy — Airo TV
description: Privacy Policy for the Airo TV application
permalink: /legal/privacy-policy/
---

# Privacy Policy

**Last Updated: July 26, 2026**

---

## Introduction

Airo TV is built by **DevelopersCoffee** as a Free application. This app is
provided at no cost and is intended for use "as is".

This page is used to inform visitors regarding our policies with the
collection, use, and disclosure of Personal Information if anyone decides
to use our Service.

If you choose to use our Service, then you agree to the collection and use
of information in relation to this policy. The Personal Information that we
collect is used for providing and improving the Service. We will not use or
share your information with anyone except as described in this Privacy Policy.

The terms used in this Privacy Policy have the same meanings as in our
[Terms and Conditions](/airo/legal/terms-conditions/) unless otherwise
defined in this Privacy Policy.

---

## Information Collection and Use

For a better experience, while using our Service, we may require you to
provide us with certain personally identifiable information. The information
that we request will be retained on your device and is **not collected by
us** in any way.

### Data We Collect (On-Device Only)

- **User preferences** — stored locally on your device
- **IPTV playlist URLs** — user-provided, stored locally on your device
- **Playback and playlist cache data** — stored locally when needed for app
  functionality
- **Favorites and channel filter selections** — stored locally on your device
- **Electronic Program Guide (EPG) data** — downloaded from the XMLTV source
  you configure, parsed on-device, and cached locally

None of the above is transmitted to DevelopersCoffee. It stays on your
device and is removed when you uninstall the app or clear its storage.

### Data We Do NOT Collect

- Personal identification information (name, email, address)
- Location data
- Contact information
- Financial or payment information
- Viewing habits, watch history, or analytics sent to external servers
- Advertising identifiers

Airo TV integrates no advertising, analytics, or attribution SDK of any
kind. There is no Google Analytics, Firebase Analytics, or Crashlytics in
the application.

### Permissions We Request

The Airo TV build requests only what a network media player needs:
internet and network-state access, multicast (for local network stream
discovery), foreground-service and wake-lock permissions (to keep playback
alive), notification posting (for playback controls), and boot-completed.
It does **not** request access to contacts, calendar, location, camera,
microphone, or device storage.

---

## On-Device Processing

Airo TV processes all data locally on your device. Specifically:

- **IPTV playlist parsing** is performed entirely on-device.
- **Channel matching and enrichment** is performed entirely on-device (see
  "Network Connections" below).
- **Cast analytics logging is disabled** when initializing Google Cast support.
- **No user data is transmitted** to DevelopersCoffee servers or any
  third-party analytics services.

Your streaming content and playlist URLs **never leave your device** except
when your TV/device requests the stream or playlist URL that you chose to load.

---

## Network Connections

Airo TV contacts the following hosts. We list them so you know exactly what
the app talks to and what is — and is not — sent.

**Servers you choose.** The M3U playlist URL and the XMLTV program-guide URL
you enter are requested directly by your device, along with the stream URLs
those playlists contain. Airo TV does not proxy, mirror, or inspect this
traffic, and it is not routed through DevelopersCoffee. The operators of
those servers will see your IP address, as they would with any media player.

**`iptv-org.github.io`.** To display channel names, countries, and languages,
Airo TV downloads three public catalogue files from the community-maintained
iptv-org project. This is a plain download of public data. **Your playlist is
not uploaded and your channel list is not sent anywhere** — the catalogue is
fetched in full and matched against your channels entirely on your own device.

**Google Firebase.** Airo TV includes the Firebase core library so the app can
initialize at startup. It does **not** include Firebase Analytics, Crashlytics,
or Cloud Messaging, so no usage data, crash data, or push tokens are gathered
through Firebase. Where Firebase generates a **Firebase installation ID**, that
is a random, per-installation identifier that is not linked to you, not tied to
any account, and reset when you uninstall the app or clear its data. It is
never combined with your playlist data and is never used for advertising or
cross-app tracking. Google's handling of it is governed by the
[Google Privacy Policy](https://policies.google.com/privacy). Airo TV
generates and shares no other identifier.

---

## IPTV Content Disclaimer

Airo TV is a **media player application only**. It does **NOT** provide,
host, or distribute any content, channels, playlists, or streams.

- All content displayed in Airo TV is **added by the user**.
- Users are solely responsible for ensuring that the content they access
  through Airo TV is legal in their jurisdiction.
- DevelopersCoffee does **NOT** endorse, promote, or facilitate the
  streaming of copyright-protected material without proper authorization
  from the rights holder.

---

## Log Data

In the event of an error in the app, we may collect data and information
(through third-party products) on your device called Log Data. This Log
Data may include information such as your device's Internet Protocol ("IP")
address, device name, operating system version, the configuration of the
app when utilizing our Service, the time and date of your use of the
Service, and other statistics.

This data is used solely for diagnosing crashes and improving app stability.

---

## Cookies

This Service does not use "cookies" explicitly. However, the app may use
third-party code and libraries that use "cookies" to collect information
and improve their services. You have the option to either accept or refuse
these cookies and know when a cookie is being sent to your device. If you
choose to refuse our cookies, you may not be able to use some portions of
this Service.

---

## Service Providers

We do not employ third parties to process personal data on our behalf, and
no third party receives personal information about you from us.

The only external services Airo TV interacts with are the ones named under
"Network Connections" above: Google Firebase (core library only, no
analytics or crash reporting), the public iptv-org catalogue, and whatever
playlist, program-guide, and stream servers you choose to configure.

---

## Data Retention

Because Airo TV keeps your data on your device rather than on our servers,
retention is under your control:

- **Preferences, playlist URLs, favorites, and filter selections** are kept
  until you change them, clear the app's storage, or uninstall the app.
- **Playlist and EPG caches** are kept until refreshed or superseded, and are
  removed with the app's storage.
- **The Firebase installation ID** persists for the life of the installation
  and is reset when you clear the app's data or uninstall.

DevelopersCoffee holds no user data, so there is nothing for us to retain or
delete on your behalf.

---

## Your Privacy Rights

Rights such as access, correction, deletion, portability, restriction, and
objection under the GDPR, and the rights to know, delete, correct, and opt
out of sale or sharing under the CCPA/CPRA, generally apply to data a company
holds about you.

**DevelopersCoffee does not collect, receive, or store personal data about
Airo TV users**, so there is no profile for us to disclose, export, correct,
or erase. We do not sell or share personal information, and we never have.

You can exercise the practical equivalent of these rights directly and at any
time: clear the app's storage or uninstall Airo TV to erase everything it
holds, and edit or remove your playlist and EPG sources in Settings. If you
believe we nonetheless hold information about you, contact us at the address
below and we will respond within 30 days. Users in the EU/EEA and the UK also
have the right to lodge a complaint with their local supervisory authority.

---

## Security

We value your trust in providing us your Personal Information, thus we
are striving to use commercially acceptable means of protecting it. But
remember that no method of transmission over the internet, or method of
electronic storage is 100% secure and reliable, and we cannot guarantee
its absolute security.

One point worth understanding about stream security: many real-world IPTV
providers serve playlists and streams over plain, unencrypted HTTP. Airo TV
permits cleartext connections so those sources remain playable. This means
that **if the playlist or stream URL you supply uses `http://` rather than
`https://`, that traffic is not encrypted** and may be visible to your
network operator or internet provider. Airo TV's own connections use HTTPS.
Prefer `https://` sources where your provider offers them.

---

## Children's Privacy

This Service does not address anyone under the age of 16. We do not
knowingly collect personally identifiable information from children under
16 years of age. In the case we discover that a child under 16 has
provided us with personal information, we immediately delete this from
our records. If you are a parent or guardian and you are aware that your
child has provided us with personal information, please contact us so
that we will be able to take the necessary actions.

We encourage parents and guardians to observe, participate in, and/or
monitor and guide their children's online activity.

---

## Links to Other Sites

This Service may contain links to other sites. If you click on a
third-party link, you will be directed to that site. Note that these
external sites are not operated by us. Therefore, we strongly advise
you to review the Privacy Policy of these websites. We have no control
over and assume no responsibility for the content, privacy policies, or
practices of any third-party sites or services.

---

## Changes to This Privacy Policy

We may update our Privacy Policy from time to time. Thus, you are advised
to review this page periodically for any changes. We will notify you of
any changes by posting the new Privacy Policy on this page.

This policy is effective as of **July 26, 2026**.

---

## Contact Us

If you have any questions or suggestions about our Privacy Policy, do
not hesitate to contact us:

- **Developer**: DevelopersCoffee
- **Email**: [coffee.devloper@gmail.com](mailto:coffee.devloper@gmail.com)
- **GitHub**: [github.com/DevelopersCoffee/airo](https://github.com/DevelopersCoffee/airo)
