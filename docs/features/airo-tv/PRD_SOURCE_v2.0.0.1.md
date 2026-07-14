ChatGPT Pro




Today 4:53 AM
Airo TV — Product Requirements Document (PRD)
Version: 1.0
Status: Draft
Platform: iOS, Android, Android TV, Apple TV, macOS
Positioning: AI-powered BYOC (Bring Your Own Content) IPTV & Media Hub

Executive Summary
Airo TV is not an IPTV provider.

It is an AI-powered media operating system that helps users organize, discover, watch and interact with their own legally obtained playlists (M3U, Xtream, Jellyfin, Emby, Plex, SMB, WebDAV, local media, etc.).

The competitive advantage is not content.

The competitive advantage is Intelligence.

Instead of acting like VLC with playlists, Airo TV behaves like an AI assistant sitting on top of the user's personal media sources.

Vision
Build the world's smartest personal television interface.

Every interaction should feel like talking to a knowledgeable assistant instead of navigating menus.

Instead of:

Sports → UK → ESPN → HD → ESPN UK HD Backup 2

Users simply say:

"Play today's Arsenal match."

Product Goals
Primary Goals
Best IPTV UX in the market

Fastest channel discovery

Zero configuration experience

Local AI processing

Beautiful UI

Privacy-first

Business Goals
Acquire paying subscribers because of software quality—not because of media.

Revenue comes from:

AI Features

Cloud Sync

Multi-device

Premium UI

Smart Automation

NOT content.

Target Users
Persona 1
Casual User
Age:
25-55

Needs

"I just want TV that works."

Pain

Cannot understand IPTV apps.

Success

Voice search everything.

Persona 2
Sports Fan

Needs

Find live matches instantly.

Pain

500 sports channels.

No idea which one works.

Success

One sentence.

Play Barcelona vs Liverpool.

Persona 3
Power User

Owns

20 playlists

40,000 channels

Several EPG providers

Needs

Organization

Deduplication

Automation

Persona 4
Family

Needs

Safe television.

Different profiles.

Kids mode.

AI parental controls.

Product Architecture
                UI

                 │

      AI Command Layer

                 │

 Playlist Intelligence Engine

                 │

      Media Provider Layer

 ├── M3U
 ├── Xtream
 ├── Jellyfin
 ├── Plex
 ├── SMB
 ├── Local Media
 ├── WebDAV
 └── DLNA

                 │

      Video Player Engine

                 │

      AI Processing Layer

                 │

 On-device LLM + Smart Models
Core Modules
Module 1
Content Sources

Supported

M3U

Xtream Codes

Stalker Portal (optional)

Jellyfin

Plex

Emby

Local files

NAS

SMB

FTP

SFTP

WebDAV

Requirements

Unlimited playlists

Automatic sync

Background refresh

Credential storage

Encrypted storage

Offline cache

Module 2
Playlist Intelligence Engine

Purpose

Convert ugly playlists into structured content.

Input

Messy M3U

Output

Netflix-style catalog

Capabilities

Duplicate detection

Broken stream detection

Channel normalization

Logo fetching

EPG mapping

Genre classification

Language detection

Country detection

Resolution detection

HDR detection

Audio language detection

Favorite prediction

Pipeline

Playlist

↓

Parse

↓

Normalize

↓

Deduplicate

↓

Health Check

↓

EPG Match

↓

AI Classification

↓

Recommendations

↓

User Dashboard
Module 3
Voice AI

Primary Feature

Hold remote button

Speak naturally.

Examples

Find today's F1 race.

Show me Hindi comedy movies.

Switch to BBC News.

Play Cartoon Network.

Find 4K nature documentaries.

Continue yesterday's movie.

Show channels from Japan.

Only English commentary.

Skip ads.

Search by actor.

Search by team.

Search by tournament.

Search by year.

Search by language.

Search by quality.

Search by genre.

Search by mood.

Intent Categories

Playback

Discovery

Navigation

Settings

Search

Filtering

Recommendations

Help

Module 4
AI Search

Traditional IPTV

Search:

ESPN

Airo

Search:

Show sports channels with English commentary broadcasting Formula One today.

Supported Search

Semantic

Natural language

Metadata

Teams

Actors

Countries

Events

Genres

Collections

Time

Module 5
Live Match Finder

Dedicated Sports AI

Capabilities

Identify

Current event

Language

Working streams

Best quality

Lowest latency

Preferred commentary

Preferred country

Favorite broadcaster

Example

User

Play India vs Australia

AI

Searches

ESPN

Star Sports

Willow

Sky

Sony

Ranks

Quality

Latency

Language

Availability

Starts playback.

Module 6
AI Catch-Up

Problem

User joins live content late.

Solution

Summarize previous events.

Sources

Closed captions

Subtitles

Audio transcription

Generated summary

Example

Catch me up

↓

Last 20 minutes

↓

Bullet summary

↓

Important moments

↓

Current topic

Module 7
Recommendations

Unlike Netflix

No cloud.

Entire recommendation engine runs locally.

Signals

Viewing history

Time

Device

Favorites

Completion

Genres

Seasonality

Language

Current live events

Recommendation Types

Continue Watching

Trending In Your Sources

Tonight's Picks

Because You Like...

Live Now

Recently Added

Hidden Gems

Module 8
Smart EPG

Capabilities

Automatic matching

Multiple providers

Fallback matching

Missing metadata repair

Poster generation

Description enhancement

Schedule correction

Conflict resolution

Module 9
Profiles

User Profiles

Adult

Kids

Guest

Sports

Movies

Anime

Each profile stores

Favorites

History

Restrictions

Recommendations

Watch progress

Voice profile

Module 10
Parental AI

Unlike PIN protection.

Rules

No horror

No adult

No gambling

No violence

School hours only

Weekend only

Time restrictions

Language restrictions

Age restrictions

Genre restrictions

Example

Block violent content weekdays 2-8 PM.

Module 11
Video Player

Requirements

HLS

MPEGTS

DASH

RTMP

MKV

MP4

AVI

HDR

Dolby Vision

Dolby Atmos

5.1

Subtitles

Picture in Picture

External audio

Playback speed

Recording

Timeshift

Multi-audio

Module 12
Smart Channel Health

Background checks

Latency

Bitrate

Availability

Resolution

Buffer prediction

Dead streams

Auto failover

Ranking

Working

Quality

Latency

Preferred language

Preferred provider

Module 13
Offline AI

Models

Gemma Nano

Phi

Llama

Mistral Small

Use Cases

Search

Recommendations

Summaries

Classification

Voice

Natural language

Everything offline.

Premium Features
Free

One playlist

Ads

Basic player

Manual search

Favorites

Premium

Unlimited playlists

Voice AI

Catch-up

Recommendations

Cloud sync

Widgets

Themes

No ads

Advanced search

Multi-window

Recording

Timeshift

Playlist cleanup

AI summaries

Smart EPG

Cloud Features
Optional

Encrypted

Sync

Profiles

Favorites

History

Settings

Playlist metadata

Never upload

Videos

Credentials

Viewing habits

Voice recordings

Monetization
Free
One playlist

Banner ads

Basic player

Basic EPG

Manual search

Premium
Monthly

Yearly

Lifetime (optional)

Unlocks

Everything AI.

AI Engine
Components

Intent detection

Search ranking

Recommendation engine

Entity extraction

Speech recognition

Summarization

Metadata enhancement

Classification

Security
Encrypted credentials

Local AI

No analytics by default

Biometric app lock

Private mode

Encrypted sync

Secure keychain

App Store Compliance
Must never include

Playlists

Channels

Pirated content

Recommendations to illegal services

Marketing

"Bring your own content."

Performance Requirements
Cold start

<2 seconds

Voice response

<500 ms

Channel switch

<1 second

Playlist parsing

100,000 channels

Under 15 seconds

Memory

<400 MB

Background battery usage

Minimal

Success Metrics
Technical

99.5% playback success

Voice accuracy >95%

Broken stream detection >98%

Playlist parsing success >99%

Business

Free → Premium conversion

20%

Monthly retention

80%

Daily active users

60%

Average session

2+ hours

Subscription renewal

85%

Future Roadmap
Phase 1 (MVP)
BYOC playlist support (M3U, Xtream)

Fast native player with EPG

AI-powered playlist cleanup (deduplication, grouping, logo/EPG matching)

Natural language search (text input)

Profiles, favorites, continue watching

Free + Premium subscription model

Phase 2
Voice assistant with on-device speech recognition

AI recommendations

Smart channel health monitoring and automatic failover

Cloud sync for preferences and profiles

Jellyfin, Plex, Emby integration

Phase 3
AI "Catch Me Up" summaries using captions/transcripts

Advanced parental AI with contextual rules

Multi-view (watch multiple channels simultaneously)

Timeshift and recording

Cross-device handoff and second-screen experience

Phase 4
AI agents that proactively surface content ("Your favorite team's match starts in 10 minutes.")

Conversational TV guide ("What's worth watching tonight?")

Smart home integration

Local automation workflows and extensibility APIs

Key Product Principles
Every feature should reinforce these five pillars:

AI-first, not menu-first — users should be able to ask instead of browse.

Privacy by design — AI processing stays on-device whenever possible.

BYOC only — Airo TV never provides, bundles, or sells copyrighted content.

Instant performance — responsiveness is a competitive advantage.

Premium experience — users pay for intelligence, reliability, and design, not for access to media.

This PRD provides a strong foundation for a subscription-based AI media platform that can evolve beyond IPTV into a universal personal media operating system while remaining compliant with app store policies.


Today 6:21 AM
This should become Volume 7, defining Airo TV’s legacy-device strategy, minimum Android support policy, constrained hardware modes, certification framework, and graceful feature degradation.

Airo TV Product Requirements Document
Volume 7 — Legacy Android TV Support, Constrained Hardware Optimization and Maximum Device Reach
Document status: Draft
Version: 1.0
Primary objective: Support the widest practical range of Android-based televisions and streaming devices without compromising security, playback reliability or product quality
Initial Android baseline: Android 8.0 / API 26
Stretch baseline: Earlier Flutter-supported Android versions, subject to dependency, security and device certification
Primary target classes: Android TV, Fire TV, AOSP television boxes, operator boxes and low-cost HDMI streaming devices

1. Purpose
This document defines how Airo TV should support older and resource-constrained Android television devices.

Airo TV should provide meaningful value on hardware that may have:

Android 8 or Android 9

1 GB to 2 GB of RAM

Limited available storage

Entry-level ARM processors

Older graphics drivers

A single reliable hardware video decoder

Slow internal flash storage

Weak or unstable Wi-Fi

Outdated vendor firmware

Limited background-process capacity

Inconsistent remote-control implementations

The objective is not to run every premium feature on every device.

The objective is to ensure that every certified device can deliver:

Fast startup

Reliable playback

Predictable remote navigation

Secure pairing

Phone-assisted discovery

Direct media handoff

Basic EPG access

Stream recovery

A polished but appropriately simplified interface

2. Product Principle
Older televisions should function as lightweight, reliable playback receivers rather than overloaded media-processing computers.

A modern phone, tablet, desktop or Airo home node may perform:

Large playlist indexing

AI inference

Metadata enrichment

EPG processing

Search ranking

Artwork processing

Stream-health analysis

Provider configuration

The television should prioritize:

Playback

Focus navigation

Receiver control

Session state

Essential metadata

Stream diagnostics

Secure communication

3. Maximum Android Reach Policy
3.1 Support Objective
Airo TV should support as many Android versions as can be supported responsibly through:

Flutter

Native Android APIs

Media engine dependencies

Security libraries

Google Play requirements

Fire OS compatibility

Supported CPU architectures

Real-device testing

The team must not choose a higher minimum SDK merely for development convenience unless required by a critical dependency or security constraint.

3.2 Proposed Support Levels
Tier 1 — Fully Supported
Initial target:

Android 10 and newer

Modern Fire TV devices

Devices meeting standard hardware requirements

Receives:

Full television interface

Rich artwork

EPG

Phone remote

Playback handoff

Stream failover

Voice-triggered actions from companion devices

Selected animations

Multi-view where hardware permits

Cloud continuity

Advanced diagnostics

Tier 2 — Legacy Optimized
Initial target:

Android 8 and Android 9

Older Fire TV and Android TV hardware

Devices with limited RAM and storage

Receives:

Lightweight television interface

Direct playback handoff

D-pad navigation

Basic search

Compact EPG

Phone remote

Secure local control

Cloud-assisted sessions

Stream recovery

Reduced artwork density

Reduced animations

Limited background tasks

Tier 3 — Experimental Extended Support
Potential target:

Android versions below API 26 that remain compatible with Flutter and required native dependencies

Vendor-specific or uncertified AOSP television boxes

Support is permitted only if:

Application installation succeeds reliably.

Required cryptography works.

TLS requirements can be met.

Native media libraries remain compatible.

Hardware decoding works for baseline formats.

Flutter rendering is stable.

Remote input behaves predictably.

Crash and memory behavior meets minimum standards.

Tier 3 devices may be distributed outside primary store channels where legally and operationally appropriate.

3.3 Support Is Defined by Capability, Not OS Alone
Android version must not be the only compatibility signal.

Two devices running the same OS may differ significantly in:

Available RAM

GPU drivers

Decoder support

CPU architecture

Storage

Vendor modifications

Remote firmware

Network quality

WebView version

Security patch level

Airo TV must determine a runtime device profile after installation.

4. Android Version Policy
4.1 Minimum SDK
The initial production configuration should target a minimum SDK that is:

Compatible with required Flutter releases

Compatible with the selected video engine

Compatible with secure networking

Compatible with local discovery

Compatible with required storage APIs

Compatible with store-distribution rules

Tested on real television hardware

A proposed starting point is:

android {
    defaultConfig {
        applicationId "com.airotv.app"
        minSdkVersion 26
        targetSdkVersion <current-required-target>
    }
}
The target SDK must follow current store requirements and be updated independently from the minimum supported Android version.

4.2 Lowering the Minimum SDK
The team should evaluate support below API 26 only after validating:

Flutter framework compatibility

Plugin minimum SDKs

Media backend support

Secure transport support

Background-service behavior

Local-network discovery

Storage access

Notification behavior

Remote key events

Build size

Crash rates

Device availability in the target market

No lower API version should be advertised as supported until it passes certification.

4.3 Dependency Governance
Every dependency must declare:

Minimum Android API

Required native architecture

Binary size

Memory impact

Background behavior

ProGuard or R8 requirements

Hardware-decoder assumptions

Maintenance status

Known television issues

A dependency that unnecessarily raises the minimum API must be:

Replaced,

Forked,

Isolated behind an optional feature module, or

Justified as business-critical.

5. Device Capability Profiling
5.1 Runtime Device Profile
On first launch, Airo TV should collect a local capability profile.

Example:

{
  "androidApi": 28,
  "platform": "android_tv",
  "manufacturer": "Amazon",
  "modelClass": "legacy_streaming_stick",
  "cpuArchitecture": "armv7",
  "ramClassMb": 1536,
  "availableStorageMb": 620,
  "gpuClass": "low",
  "maxHardwareResolution": "1080p",
  "supportedVideoCodecs": [
    "h264"
  ],
  "supportedAudioCodecs": [
    "aac",
    "ac3"
  ],
  "maxConcurrentDecoders": 1,
  "networkClass": "wifi_5_2ghz",
  "deviceTier": "legacy_optimized"
}
5.2 Capability Inputs
The profile should consider:

Android API level

Device model

CPU architecture

Number of CPU cores

Memory class

Available storage

GPU renderer

Hardware codec list

Maximum decoder resolution

HDR support

Audio passthrough support

Concurrent decoder count

Network interface

Bluetooth capability

Remote key availability

Thermal APIs

Vendor-specific restrictions

5.3 Dynamic Reclassification
A device may temporarily enter a more constrained mode because of:

Low memory

Low storage

Thermal pressure

Active multi-view

Background recording

Network instability

Repeated decoder failures

Battery constraints on portable displays

The application should adapt during runtime.

6. Legacy Receiver Mode
6.1 Purpose
Legacy Receiver Mode is the default operating profile for devices that cannot safely run the full Airo TV experience.

It should preserve the premium character of the application while limiting resource-intensive features.

6.2 Legacy Receiver Home Screen
The home screen should prioritize:

Continue watching

Live now

Favorites

Recent channels

Paired-device status

Search from phone

Current program

Settings

Diagnostics

Avoid:

Dozens of horizontal shelves

Animated backgrounds

Full-screen autoplay previews

Heavy blur effects

Continuously updating posters

Large recommendation graphs

Embedded AI inference

6.3 Content Browsing
The television should avoid loading entire 50,000-item or 100,000-item catalogs.

Use:

Paginated database queries

Server- or phone-provided search results

Recent-item caches

Favorite collections

Category subsets

Time-windowed EPG data

Incremental artwork loading

6.4 Companion-First Discovery
For highly constrained devices, the preferred experience is:

User searches on phone
        ↓
Phone resolves content
        ↓
User selects legacy television
        ↓
TV receives secure media reference
        ↓
TV plays directly from source
The television must still support standalone playback for cached, favorite and recent content.

7. Feature Availability Matrix
Feature	Standard TV	Legacy Optimized TV	Experimental Device
Direct HLS playback	Yes	Yes	Required
VOD playback	Yes	Yes	Required
Phone remote	Yes	Yes	Preferred
Secure local pairing	Yes	Yes	Required
Cloud device discovery	Yes	Yes	Optional
Full local playlist indexing	Yes	Limited	Optional
Phone-assisted search	Yes	Yes	Preferred
Full EPG history	Yes	No	No
Current and next EPG	Yes	Yes	Preferred
AI inference on TV	Optional	No	No
Multi-view	Hardware dependent	No	No
Animated previews	Optional	No	No
Blur-heavy UI	Limited	No	No
Local recording	Hardware dependent	Usually no	No
Stream failover	Yes	Yes	Preferred
Local file proxy playback	Yes	Yes	Hardware dependent
HDR	Hardware dependent	Hardware dependent	Not guaranteed
4K playback	Hardware dependent	Not guaranteed	Not guaranteed
8. Video Playback Requirements
8.1 Direct Playback First
The receiver should fetch media directly from:

IPTV provider

VOD server

NAS

Jellyfin

Plex

Emby

Desktop node

Temporary phone media server

The phone must not proxy internet-hosted content.

8.2 Native Decoding
Video decoding must occur through native hardware-accelerated APIs wherever possible.

Preferred paths may include:

Android MediaCodec

Android Media3

MPV with hardware acceleration

LibVLC where compatibility requires it

FFmpeg-assisted demuxing

Surface-based rendering

Decoded video frames must not pass through Dart memory.

8.3 Baseline Codec Profile
Every certified legacy device should be tested for:

H.264 AVC

AAC audio

MPEG-TS

HLS

MP4

Common subtitle formats

720p and 1080p playback where supported

Optional:

HEVC

AV1

VP9

AC-3

E-AC-3

DTS

HDR

Dolby Vision

Unsupported formats must produce a clear compatibility message or choose an alternate source.

8.4 Playback Fallback Strategy
Preferred source
      ↓
Preferred hardware decoder
      ↓
Alternative hardware configuration
      ↓
Alternative media backend
      ↓
Backup stream
      ↓
Reduced resolution
      ↓
Compatibility error
Software decoding should be restricted on weak television hardware.

9. Local Phone Media Streaming
9.1 Applicable Use Case
A temporary phone media server should be used only when:

The media file exists only on the phone.

The television cannot access the file directly.

The user explicitly chooses the television as receiver.

The file does not require unsupported transcoding.

9.2 HTTP Requirements
The temporary server must support:

HTTP GET

HTTP HEAD

Byte-range requests

206 Partial Content

Accurate Content-Length

Content-Range

MIME type detection

Seek requests

Connection keep-alive

Cancellation

Temporary access tokens

Session expiry

Adding only Accept-Ranges: bytes is not sufficient. The server must correctly parse the requested range and return the matching file segment.

9.3 Memory Requirement
The television should stream sequentially and maintain a bounded playback buffer.

The system must not assume a fixed memory ceiling such as 50 MB across all devices.

Buffer size should be selected according to:

Available memory

Bitrate

Network stability

Decoder requirements

Stream type

Seek behavior

9.4 Phone Battery Protection
When the phone is the only available source:

Prefer direct file serving without transcoding.

Use efficient native file reads.

Avoid keeping the display awake.

Stop serving when playback ends.

Stop serving when the session expires.

Warn users about battery consumption.

Prefer charging for long sessions.

Reject hosting during critical battery or thermal state.

Offer desktop or NAS migration when available.

10. Flutter UI Optimization
10.1 Rendering Rules
Legacy devices should avoid:

Runtime blur filters

Large translucent overlays

Complex clipping

Multiple nested animated widgets

Full-screen shader effects

Large hero transitions

Constant parallax

Auto-playing video thumbnails

Multiple simultaneous image fades

Oversized decoded posters

10.2 Approved Visual Style
Use:

Solid or lightly transparent surfaces

Simple focus scaling

Controlled elevation

Short transitions

Static backgrounds

Reduced poster counts

Pre-sized artwork

Placeholder-first loading

Strong focus borders

Limited shadow layers

10.3 Animation Policy
Animation should be classified as:

Essential
Focus transition

Screen transition

Loading indicator

Playback feedback

Optional
Poster fade

Shelf movement

Background art transition

Disabled in Legacy Mode
Continuous ambient animation

Auto-playing previews

Heavy blur transitions

Particle effects

Multi-layer parallax

Animated gradients

11. Widget and State Optimization
11.1 Rebuild Boundaries
The app must:

Isolate playback state from home-screen rebuilds.

Rebuild only the focused item when focus changes.

Keep timer updates away from full-screen widgets.

Use selectors for small state fragments.

Avoid subscribing complete screens to global state.

Cache immutable view models.

Use stable keys.

Avoid recreating focus nodes during list updates.

11.2 Long-List Requirements
Virtualize rows and grids.

Paginate database access.

Prefetch only a small number of upcoming items.

Cancel artwork requests for off-screen items.

Retain focus safely during page loading.

Never construct an entire playlist as widgets.

Avoid synchronous sorting on the UI isolate.

Use incremental results.

11.3 Image Optimization
Request artwork at rendered size.

Use compressed thumbnails.

Cap image cache by device tier.

Avoid full-resolution posters on television cards.

Store lower-resolution artwork variants.

Decode images outside critical interaction paths.

Use placeholders that preserve card dimensions.

Prefer local cached images over repeat network fetches.

12. Focus and Remote Performance
12.1 Focus Requirements
The TV interface must remain fully navigable through:

D-pad

Select

Back

Play or pause

Channel controls where available

Number keys where supported

12.2 Focus Optimization
Focus movement must not trigger complete shelf rebuilds.

Focus state should be local to the visible section.

Initial focus must always be defined.

Poster loading must not move focus targets.

Rapid D-pad input must be debounced without feeling delayed.

Focus should restore after playback.

Dialogs must return focus to the invoking control.

12.3 Perceived Response Target
Key event processing: under 50 ms

Visible focus transition: under 100 ms

Screen opening from cache: under 500 ms where possible

No unbounded focus animation queue

13. Memory Management
13.1 Memory Budgets
Each device tier must define budgets for:

Flutter heap

Native heap

Media decoder

Video buffer

Artwork cache

Database cache

EPG data

Network buffers

Protocol state

13.2 Legacy Mode Memory Rules
One primary playback engine.

No background preview players.

No on-device LLM.

Small image cache.

Limited EPG window.

No full catalog in memory.

No multiple decoded background images.

No hidden retained screens with heavy lists.

Release resources immediately after playback.

Pause background indexing during playback.

13.3 Memory Pressure Response
When the system reports memory pressure:

Clear off-screen images.

Reduce artwork cache.

Stop metadata enrichment.

Cancel stream probing.

Unload optional screens.

Reduce EPG window.

Disable previews.

Release unused media engines.

Preserve current playback.

Playback must receive the highest resource priority.

14. Storage Optimization
14.1 Storage Goals
Legacy TV devices should not store:

Full movie files by default

Large poster libraries

Long EPG history

AI models

Duplicate playlists

Extensive diagnostics

Temporary media transfers after playback

14.2 Compact Local Data
Store:

Favorites

Recent items

Essential media identifiers

Current and next EPG

Paired-device keys

Minimal account state

Stream-health summary

Small artwork cache

Playback progress

Device capabilities

14.3 Low-Storage Mode
Trigger when available storage falls below a configured threshold.

Actions:

Stop nonessential downloads.

Remove temporary files.

Reduce artwork cache.

Remove expired EPG data.

Disable recording.

Disable offline downloads.

Suspend model installation.

Show actionable storage guidance.

Preserve credentials, favorites and watch progress.

15. Network Reliability
15.1 Weak Wi-Fi Handling
Legacy devices often have weaker radios.

Airo TV should:

Detect repeated packet loss.

Use bounded reconnect attempts.

Preserve playback position.

Switch to backup sources.

Reduce selected bitrate.

Prefer 1080p or 720p over unstable 4K.

Warn users when the network is the likely bottleneck.

Distinguish provider failure from local Wi-Fi failure.

15.2 Reconnection Policy
Recommended phases:

Immediate retry
      ↓
Short delayed retry
      ↓
Refresh source authorization
      ↓
Try backup source
      ↓
Reduce quality
      ↓
Show recovery options
Retries must not create uncontrolled network loops.

15.3 Network Diagnostics
Legacy devices should expose:

Wi-Fi signal where available

Current bitrate

Buffer events

Packet-loss estimate

Reconnect count

DNS failures

Source response time

Local device latency

Decoder errors

16. EPG Strategy for Older Devices
16.1 Compact EPG
Legacy devices should receive only:

Current program

Next program

Configurable upcoming window

Favorite channel schedules

Recently watched channel schedules

They should not be required to parse or store large XMLTV files locally.

16.2 Distributed EPG Processing
A phone, desktop or home node should:

Download XMLTV

Decompress it

Parse it

Normalize timezones

Match channels

Create compact records

Send required subsets to the TV

16.3 Standalone Fallback
If no companion node is available, the TV may:

Download a limited time window.

Parse incrementally.

Pause parsing during playback.

Keep only required channels.

Skip artwork enrichment.

Display basic guide data first.

17. Search Strategy
17.1 Legacy TV Search
The TV should support:

Favorites

Recent channels

Prefix search

Category search

Number-key search where available

Phone keyboard

Voice search through paired phone

Cloud-assisted search where enabled

17.2 Offloaded Search
For large catalogs:

TV submits query
      ↓
Phone, desktop or cloud index searches
      ↓
Top ranked results returned
      ↓
TV displays compact list
Only the result set should be transferred to the TV.

18. AI Support Policy
18.1 No Heavy AI on Legacy TVs
Legacy devices should not run:

Large language models

Speech recognition models

Embedding generation

Long-form summarization

Full-library semantic indexing

18.2 Delegated AI
AI tasks should be delegated to:

Trusted phone

Trusted desktop

Home node

Optional cloud service

Rule-based fallback

18.3 Television AI Experience
The television may still expose:

Voice search button

Natural-language results

Smart recommendations

Catch-up summaries

Parental-rule enforcement

The processing location should remain invisible to the user unless privacy controls require disclosure.

19. Background Work Policy
19.1 Allowed During Playback
Essential state synchronization

Stream-health monitoring

Command listener

Minimal progress persistence

Required token refresh

Failover preparation

19.2 Deferred During Playback
Full playlist import

EPG decompression

Metadata enrichment

Poster prefetching

Predictive warm-up for unrelated channels

Database compaction

Large synchronization jobs

Cache cleanup

AI model work

20. Build and Binary Optimization
20.1 ABI Support
The Android application may need to support:

ARMv7

ARM64

x86 or x86_64 for development and selected devices

Release packaging should use ABI-specific bundles or splits where supported to avoid unnecessarily large installations.

20.2 Binary Size
Measure:

Flutter engine size

Media libraries

Codec libraries

Native symbols

Database engine

Artwork assets

Localization assets

Protobuf runtime

Crash-reporting libraries

Optional heavy components should be modularized where practical.

20.3 Code Shrinking
Production builds should evaluate:

R8

Resource shrinking

Native symbol stripping

Deferred components where practical

ABI splits

Asset compression

Removal of development diagnostics

Code shrinking must not break:

Native media bindings

Protobuf models

Reflection-based plugins

Platform channels

Remote-service registration

21. Security on Legacy Android
21.1 Security Limitation Awareness
Older devices may have:

Old security patches

Vendor-abandoned firmware

Outdated trust stores

Weak system components

Unsupported TLS implementations

Compromised third-party firmware

Airo TV must not assume that a supported API level means a secure device.

21.2 Security Requirements
Use modern TLS where supported.

Pin or validate critical backend certificates appropriately.

Encrypt sensitive local records.

Store credentials using the strongest available platform mechanism.

Never expose credentials through local discovery.

Require explicit device trust.

Support remote revocation.

Detect obviously rooted or compromised environments where feasible.

Allow users to restrict legacy devices to local-only control.

Avoid storing long-lived provider secrets on untrusted boxes where possible.

21.3 Restricted Trust Mode
A legacy device may be marked as a restricted receiver.

Restricted receivers may:

Receive short-lived playback tickets

Play approved content

Report playback state

Accept basic remote commands

They may not:

Receive full account credentials

Export playlists

Manage billing

Change security settings

Add trusted devices

Access unrestricted profiles

22. Store and Distribution Strategy
22.1 Google Play
The production build must:

Target the currently required SDK.

Meet television app quality requirements.

Declare leanback or television capability where appropriate.

Provide banner assets.

Work without touch input.

Support remote navigation.

Avoid unsupported background behavior.

Comply with data safety requirements.

22.2 Amazon Appstore
The Fire TV build may require:

Fire OS-specific testing

Amazon remote behavior testing

Appstore billing integration where applicable

Different service availability assumptions

Vendor-specific media compatibility rules

Store-specific packaging

22.3 Direct Distribution
Direct APK distribution may be considered for:

Unsupported app stores

Enterprise deployments

Operator boxes

Experimental legacy support

Regions with limited store availability

Direct distribution requires:

Signed updates

Secure update verification

Rollback protection

Clear permission disclosure

Version compatibility checks

23. Device Certification Program
23.1 Certification Levels
Certified
All core requirements pass.

Compatible
Core playback works, but selected premium features are unavailable.

Experimental
Installation and playback may work, but the device is not guaranteed.

Unsupported
Critical security, playback or stability requirements fail.

23.2 Certification Test Areas
Installation

Cold start

Remote navigation

Focus stability

HLS playback

VOD playback

Hardware decoding

Subtitle rendering

Audio track switching

Local pairing

Phone remote

Cloud session recovery

Stream failover

Memory pressure

Low storage

App resume

Sleep and wake

Network reconnect

Long-duration playback

Thermal behavior

Crash rate

23.3 Minimum Certification Criteria
A device must:

Install successfully.

Launch reliably.

Complete pairing.

Navigate with a D-pad.

Play baseline H.264/AAC content.

Maintain playback for an extended test session.

Recover from temporary network loss.

Avoid repeated out-of-memory crashes.

Store credentials securely enough for its trust class.

Provide a viable update path.

24. Performance Targets for Legacy Devices
Operation	Target
Cold start	Under 5 seconds
Cached home screen	Under 2.5 seconds
Remote focus response	Under 100 ms perceived
Phone command acknowledgement	Under 300 ms on LAN
Direct playback start	Under 3 seconds where source permits
Pause or resume response	Under 250 ms
Search result display from phone	Under 1 second
Current EPG display	Under 2 seconds
Recovery after brief Wi-Fi loss	Under 5 seconds
Sustained playback memory growth	Bounded
UI frame target	60 FPS where possible, stable 30 FPS minimum on certified legacy hardware
A stable interface is more important than forcing 60 FPS on hardware that cannot sustain it.

25. Graceful Degradation Rules
When device capability is insufficient:

Limitation	Airo Response
Low RAM	Enable Legacy Receiver Mode
Very low storage	Use compact metadata and minimal cache
No HEVC decoder	Select H.264 source
Weak Wi-Fi	Reduce bitrate or quality
No HDR	Select SDR source
No AI runtime	Delegate to phone or cloud
One decoder only	Disable multi-view and previews
Slow database	Use phone-assisted search
Weak GPU	Disable blur and complex animations
Old security patch	Use restricted receiver trust
No cloud connectivity	Use local-only control
Multicast blocked	Use QR pairing or cloud discovery
The user should see a useful alternative rather than a generic unsupported error.

26. User Experience Requirements
26.1 First Launch
The application should:

Detect device capability.

Select the appropriate performance profile.

Explain phone pairing benefits.

Offer QR pairing.

Run a quick playback capability check.

Configure artwork and animation limits.

Avoid downloading large datasets immediately.

26.2 Device Optimization Message
Use non-technical wording.

Example:

Airo TV has optimized the experience for this television. Search and advanced features can run on your phone while this TV focuses on smooth playback.

Avoid wording that makes the device feel defective or obsolete.

26.3 Settings
Users may choose:

Automatic optimization

Reduced motion

Low-memory mode

Compact artwork

Limited EPG

Local-only mode

Phone-assisted search

Preferred maximum quality

Hardware decoding

Advanced diagnostics

Dangerous settings should remain under Advanced Mode.

27. Telemetry and Diagnostics
27.1 Required Metrics
Collect privacy-safe measurements for:

API version

Device tier

Memory pressure

Startup time

Decoder selected

Playback failure class

Rebuffer count

App crash rate

Focus response

Search latency

Low-storage events

Feature degradation applied

Session recovery success

27.2 Privacy Rules
Do not collect:

Raw provider URLs

Credentials

Local file paths

Full viewing history without consent

Voice recordings

Network secrets

28. Testing Matrix
28.1 Android Versions
Test at minimum:

Android 8.0

Android 8.1

Android 9

Android 10

Android 11

Android 12

Android 13

Android 14

Android 15 and newer supported releases

Earlier versions should be included if extended support is pursued.

28.2 Hardware Classes
Test:

1 GB RAM TV box

1.5 GB RAM streaming stick

2 GB RAM Android TV

Older Fire TV

Current Fire TV

Vendor AOSP box

32-bit ARM device

64-bit ARM device

720p television

1080p television

4K television

Weak 2.4 GHz Wi-Fi device

28.3 Stress Tests
Eight-hour continuous playback

Repeated channel switching

Playlist refresh during idle

Phone remote during playback

Wi-Fi interruption

Router restart

Low storage

Memory pressure

App background and resume

Device sleep and wake

Decoder failure

Subtitle switching

Expired source URL

Repeated failover

Rapid D-pad navigation

29. Delivery Phases
Phase 1 — Android 8/9 Baseline
Deliver:

API 26-compatible build

H.264/AAC baseline playback

Hardware-decoder detection

Legacy Receiver Mode

D-pad navigation

QR pairing

Phone remote

Compact EPG

Low-memory profile

Exit criteria:

Core playback operates on certified Android 8 and Android 9 devices.

The interface remains responsive under constrained memory.

Phone-assisted search and handoff work reliably.

Phase 2 — Device Profiling
Deliver:

Capability scanner

Runtime tier selection

Codec inventory

Memory and storage classification

Automatic quality limits

Feature-availability matrix

Exit criteria:

Devices receive the correct mode without manual configuration.

Unsupported features are hidden or replaced with alternatives.

Phase 3 — Constrained Playback Optimization
Deliver:

Backend fallback rules

Decoder compatibility database

Weak-network recovery

Reduced buffering profiles

Stream source fallback

Long-duration stability tests

Exit criteria:

Certified legacy devices complete long playback sessions.

Playback failure recovery does not crash the application.

Phase 4 — Extended Android Evaluation
Deliver:

Lower-API dependency audit

Experimental builds

Real-device validation

Security review

Distribution assessment

Exit criteria:

Additional Android versions are added only when core certification passes.

Unsupported devices are clearly identified.

Phase 5 — Legacy Device Ecosystem
Deliver:

Restricted receiver trust mode

Home-node assistance

Offloaded EPG

Offloaded search

Cloud or phone AI delegation

Device compatibility reporting

Exit criteria:

Old televisions operate as secure, lightweight receivers.

Heavy processing remains offloaded without degrading playback.

30. Acceptance Criteria
The legacy Android support strategy is production-ready when:

Airo TV installs and launches on certified Android 8 and Android 9 devices.

Every television screen can be navigated without touch input.

Playback uses native rendering without raw frames entering Dart.

Baseline H.264/AAC media plays reliably.

Large catalogs are not loaded fully into television memory.

A paired phone can search and start playback on the television.

The TV can continue playback after the phone disconnects.

Legacy devices automatically receive a lighter interface.

AI work is delegated away from constrained televisions.

Current and next EPG data appear without local processing of full XML datasets.

Memory pressure triggers graceful cache reduction.

Low storage does not corrupt user state.

Unsupported codecs result in alternate-source selection or a clear message.

Direct cloud playback does not pass through the phone.

Phone-hosted local files support correct HTTP byte-range responses.

Remote focus remains stable while artwork loads.

Background work does not interrupt active playback.

Device capability is evaluated independently from Android version.

Legacy devices can be restricted from storing full provider credentials.

Every advertised supported device class passes extended playback testing.

The target SDK can be updated without unnecessarily dropping older runtime versions.

Dependencies that raise the minimum API are reviewed and justified.

Experimental devices are not represented as fully supported.

Core playback remains available when cloud services are offline.

31. Important Corrections and Engineering Constraints
Flutter Compatibility Does Not Guarantee Device Performance
A device may meet Flutter’s minimum Android requirement and still be unsuitable because of weak drivers, low memory or decoder problems.

Native Rendering Does Not Automatically Mean Low Memory
Flutter applications can still consume significant memory through:

Large widget trees

Artwork caches

Decoded images

Retained routes

Animations

Platform textures

Native media buffers

Memory must be actively budgeted.

Old Devices May Be Limited by Hardware, Not Interface Framework
A device without a capable HEVC or 4K decoder cannot be made into a reliable 4K receiver through software optimization alone.

Phone Streaming Does Not Fix Unsupported Codecs
If a local phone file uses a codec the television cannot decode, direct HTTP delivery will not solve compatibility. A capable desktop or home node may need to transcode it.

Range Support Requires Partial-Content Responses
A correct local media server must process the Range request header and return 206 Partial Content. Merely declaring Accept-Ranges does not enable seeking.

WebSockets Are Not a Background Guarantee
Mobile and television operating systems may suspend connections. Session recovery and platform-specific background behavior remain necessary.

Maximum Reach Must Not Override Security
Airo TV should not support an obsolete device when it cannot establish secure communication or safely protect user credentials.

32. Product Principles
Maximum Practical Reach
Support as many Android versions and device classes as can be tested and secured.

Playback First
A legacy television should be excellent at playing media even when advanced features are delegated.

Graceful Degradation
Remove expensive features before sacrificing reliability.

Companion Enhanced, Not Companion Required
A phone should improve the experience, but the TV must retain core standalone functionality.

Capability Over Version
The actual hardware profile determines feature availability.

No Artificial Minimum SDK Inflation
Do not drop users solely because a nonessential dependency requires a newer API.

Security Is a Compatibility Requirement
A device that cannot protect sessions or credentials cannot be treated as fully supported.

Preserve Device Life
Airo TV should extend the useful life of older televisions and streaming devices where technically responsible.

33. Expected Outcome
Airo TV can serve both modern and older Android television ecosystems through one adaptive product architecture.

Modern devices receive:

Rich navigation

Advanced visual effects

Multi-view

Full EPG

Local indexing

Enhanced playback features

Older devices receive:

Lightweight navigation

Fast phone-assisted search

Secure direct playback

Compact EPG

Stream recovery

Reliable D-pad interaction

Minimal storage usage

The result is not a compromised application for old televisions.

It is a deliberately optimized receiver experience that uses the broader Airo ecosystem to compensate for limited local hardware while preserving privacy, playback quality and usability.

This volume should be followed by a platform compatibility and certification specification containing exact device classes, RAM thresholds, codec profiles, Android API support, feature flags and automated benchmark gates.


else we can build airo tv as per need for older android with limited useful features so we have to make sure in our modular platform how we can give support for such usecases 

The right approach is to treat legacy-device support as a separate product profile built from shared modules, not as a reduced version of the full app created through scattered conditionals.

Airo TV Product Requirements Document
Volume 8 — Modular Product Profiles, Legacy Editions and Capability-Based Feature Delivery
Document status: Draft
Version: 1.0
Primary objective: Allow Airo TV to ship purpose-built application experiences for older and constrained devices while retaining a shared platform, common protocols and reusable core modules
Architecture model: Modular monorepo with capability-based product composition
Supported product profiles: Full, Standard, Lite Receiver, Embedded Receiver and Experimental Legacy

1. Purpose
Airo TV must support a wide range of devices without forcing every device to run the same application configuration.

The platform should be capable of producing:

A complete media application for modern televisions

A lightweight receiver application for older televisions

A remote-controlled playback client for extremely constrained devices

A companion application for mobile devices

A desktop media-management application

A home-node service

Vendor-specific or operator-specific television editions

All editions should share the same core platform where practical.

The legacy television application should not be treated as the full application with random features disabled at runtime.

It should be a deliberately composed product with:

Fewer modules

Smaller binary size

Lower memory use

Simpler navigation

Reduced storage requirements

Restricted background activity

Clearly defined capabilities

A focused playback-first experience

2. Product Strategy
Airo TV should support multiple product experiences from one platform.

                         Airo Platform
                              │
        ┌─────────────────────┼──────────────────────┐
        │                     │                      │
   Full TV App          Lite Receiver         Mobile Companion
        │                     │                      │
  Rich discovery       Playback focused        Search and control
  Full EPG             Phone assisted          AI and onboarding
  Local indexing       Compact metadata        Device management
The user should experience one ecosystem even when individual devices run different editions.

3. Core Principle
Devices should receive the smallest product that completely satisfies their useful role.

A constrained television does not need:

Full AI inference

Full catalog indexing

Large EPG history

Complex metadata management

Multiple background workers

Advanced animation systems

Multi-view

Full recording management

It may only need:

Pairing

Device presence

Playback

Favorites

Recent channels

Current program information

Phone-assisted search

Stream failover

Remote control

Playback-state synchronization

Removing unnecessary modules should improve reliability rather than make the application feel incomplete.

4. Modular Platform Architecture
4.1 Platform Layers
┌──────────────────────────────────────────────┐
│              Product Applications            │
│ Full TV │ Lite TV │ Mobile │ Desktop │ Node  │
└──────────────────────────────────────────────┘
                         │
┌──────────────────────────────────────────────┐
│              Feature Modules                 │
│ EPG │ Search │ Profiles │ AI │ Recording     │
│ Discovery │ Remote │ Multi-view │ Downloads  │
└──────────────────────────────────────────────┘
                         │
┌──────────────────────────────────────────────┐
│              Shared Core Services            │
│ Identity │ Sessions │ Media Model │ Security │
│ Playback Contract │ Sync Contract │ Errors   │
└──────────────────────────────────────────────┘
                         │
┌──────────────────────────────────────────────┐
│              Platform Adapters               │
│ Android │ Fire OS │ Apple │ Desktop │ Native │
└──────────────────────────────────────────────┘
4.2 Shared Core
Every Airo edition should reuse a minimal shared core.

Required shared modules:

Device identity

Authentication

Trusted-device management

Session model

Playback state model

Media identifiers

Source references

Command protocol

Security and encryption

Error taxonomy

Logging and redaction

Feature capability model

Version compatibility

Local configuration

These modules must remain lightweight and should not import optional product features.

4.3 Optional Feature Modules
Optional modules may include:

Full EPG

Compact EPG

Local playlist import

Remote playlist browsing

Semantic search

Basic search

AI assistant

Recommendations

Recording

Downloads

Multi-view

Metadata enrichment

Local media server

NAS browsing

Parental controls

Advanced diagnostics

Subscription management

Cloud continuity

Phone remote

Voice input

Modules should expose explicit interfaces and declare their dependencies.

5. Product Profiles
5.1 Full TV Profile
Designed for:

Modern Android TV

Modern Fire TV

High-memory television devices

Desktop-class TV hardware

Includes:

Full home experience

Local playlist indexing

Rich EPG

Search

Recommendations

Profiles

Parental controls

Cloud continuity

Stream failover

Recording where supported

Multi-view where supported

Rich artwork

Advanced diagnostics

5.2 Standard TV Profile
Designed for:

Mid-range televisions

Devices with moderate RAM and storage

Older but capable hardware

Includes:

Full playback

Local playlist browsing

Limited EPG window

Favorites

Search

Phone remote

Cloud continuity

Profiles

Stream failover

Reduced visual effects

Excludes or limits:

Multi-view

Heavy artwork

On-device AI

Long EPG history

Full background enrichment

5.3 Lite Receiver Profile
Designed for:

Android 8 and Android 9 televisions

Older Fire TV sticks

Low-memory streaming boxes

Devices intended primarily as playback targets

Includes:

Device pairing

Direct playback

Playback handoff

Phone remote

Favorites

Recent content

Current and next EPG

Basic category navigation

Compact search

Stream failover

Subtitle and audio selection

Playback-state sync

Restricted profile support

Minimal diagnostics

Excludes:

Full playlist management

Large local search index

On-device AI

Recording

Downloads

Multi-view

Full metadata enrichment

Animated previews

Large EPG storage

Complex dashboard personalization

5.4 Embedded Receiver Profile
Designed for:

Extremely constrained Android boxes

Operator hardware

Hospitality deployments

Vendor-integrated television clients

Devices where Airo operates mainly as a receiver

Includes only:

Secure activation

Device registration

Playback receiver

Remote-control commands

Playback status

Minimal now-playing UI

Basic settings

Error recovery

Software update support

All browsing, search and configuration occur on another Airo device.

5.5 Experimental Legacy Profile
Designed for:

Older Android versions

Uncertified AOSP hardware

Community-supported devices

Directly distributed builds

Includes:

Baseline playback

Pairing

Remote commands

Limited media compatibility

Basic diagnostics

Experimental editions must clearly communicate that:

Some codecs may not work.

Store distribution may not be available.

Security support may be limited.

Feature availability may vary.

Updates may be discontinued earlier than certified editions.

6. Build-Time Composition
6.1 Purpose
Features that are not needed by a product profile should be excluded from the build where practical.

This reduces:

Binary size

Startup time

Native library count

Memory overhead

Permission requirements

Attack surface

Dependency conflicts

Maintenance complexity

6.2 Application Entry Points
The monorepo may contain separate application entry points:

apps/
├── airo_tv_full
├── airo_tv_standard
├── airo_tv_lite
├── airo_receiver
├── airo_mobile
├── airo_desktop
└── airo_home_node
Each application selects the modules it requires.

6.3 Feature Bundles
Example product composition:

const liteReceiverFeatures = {
  AiroFeature.playback,
  AiroFeature.devicePairing,
  AiroFeature.remoteControl,
  AiroFeature.compactEpg,
  AiroFeature.favorites,
  AiroFeature.recentMedia,
  AiroFeature.streamFailover,
  AiroFeature.playbackSync,
};
const fullTvFeatures = {
  ...liteReceiverFeatures,
  AiroFeature.fullEpg,
  AiroFeature.localPlaylistImport,
  AiroFeature.search,
  AiroFeature.recommendations,
  AiroFeature.profiles,
  AiroFeature.recording,
  AiroFeature.multiView,
  AiroFeature.cloudContinuity,
};
These examples represent product declarations rather than scattered UI conditions.

7. Compile-Time and Runtime Feature Control
Airo TV should use two separate control layers.

7.1 Compile-Time Inclusion
Used when a feature:

Adds large native libraries

Requires unsupported APIs

Significantly increases binary size

Requires unnecessary permissions

Is fundamentally unsuitable for the device profile

Creates security or maintenance risk

Examples:

AI inference runtime

Recording engine

Transcoding

Multi-view

Full EPG parser

Local media server

Advanced metadata engine

7.2 Runtime Capability Control
Used when a compiled feature depends on:

Available RAM

Storage

Codec support

Network quality

Decoder count

Subscription tier

User preference

Thermal state

Device certification

Server-side rollout

Examples:

HDR playback

4K quality

Artwork density

Background prefetch

Rich animations

Cloud remote control

Stream warm-up

7.3 Rule
Compile-time exclusion controls what the application contains.

Runtime capability control determines what the current device can safely use.

These mechanisms must not be treated as interchangeable.

8. Capability Contract
Every edition must publish its capabilities through the shared device protocol.

Example:

{
  "deviceId": "legacy-tv-01",
  "productProfile": "lite_receiver",
  "capabilities": {
    "playback": true,
    "localPlaylistImport": false,
    "remoteSearch": true,
    "localSearch": "basic",
    "epgWindowHours": 24,
    "aiInference": false,
    "multiView": false,
    "recording": false,
    "cloudContinuity": true,
    "maxResolution": "1080p",
    "maxConcurrentDecoders": 1
  }
}
Controllers should use this contract to determine:

Which actions to show

Which features to delegate

Which media source to select

Whether a handoff is valid

Whether transcoding is required

Whether a result should be rendered locally or remotely

9. Feature Dependency Graph
Every optional module must declare its required dependencies.

Example:

Multi-view
├── Playback core
├── Multiple decoder support
├── Advanced layout
└── High-memory device profile

Full EPG
├── EPG parser
├── EPG database
├── Timezone normalization
└── Extended storage

AI search
├── Search index
├── AI provider
├── Model manager
└── Capability router
The build system must prevent invalid combinations.

For example:

Multi-view cannot be enabled without decoder-capability detection.

Full EPG cannot be included without appropriate storage support.

AI inference cannot be enabled without model lifecycle management.

Recording cannot be enabled without storage checks.

10. Shared Contracts, Different Implementations
Modules should use shared interfaces while providing profile-specific implementations.

10.1 EPG Example
EpgRepository
├── FullLocalEpgRepository
├── CompactLocalEpgRepository
├── RemoteEpgRepository
└── NoOpEpgRepository
A full television may use FullLocalEpgRepository.

A legacy receiver may use CompactLocalEpgRepository.

An embedded receiver may use RemoteEpgRepository.

10.2 Search Example
SearchProvider
├── LocalIndexedSearch
├── LightweightPrefixSearch
├── CompanionDelegatedSearch
├── CloudSearch
└── CompositeSearch
The UI consumes the SearchProvider interface without knowing where the search executes.

10.3 AI Example
AiProvider
├── LocalAiProvider
├── CompanionAiProvider
├── HomeNodeAiProvider
├── CloudAiProvider
└── RulesFallbackProvider
Legacy devices may use CompanionAiProvider without containing an AI runtime.

11. Delegation Framework
11.1 Purpose
When a device cannot perform a feature locally, it should be able to request the capability from another trusted node.

Delegatable operations include:

Search

Playlist parsing

EPG processing

Metadata matching

AI intent parsing

Subtitle lookup

Stream-health ranking

Artwork resizing

Source resolution

Credential-assisted playback

Transcoding

11.2 Delegation Flow
Legacy TV requests operation
           ↓
Capability router finds eligible node
           ↓
Phone, desktop or home node accepts task
           ↓
Task executes remotely
           ↓
Compact result returns to TV
           ↓
TV displays or plays result
11.3 Delegation Requirements
Tasks must have unique identifiers.

The requesting device must declare timeout limits.

Results must be versioned.

Sensitive requests must use encrypted payloads.

A delegated node must confirm its capability.

Tasks must be cancellable.

Duplicate task execution must be prevented.

The legacy TV must have a fallback when no helper node is available.

The user must be informed when a required companion is unavailable.

12. Remote Data Views
Constrained devices should consume compact remote views instead of full datasets.

Examples:

Top 20 search results instead of a complete catalog

Current and next program instead of seven days of EPG

Favorite channels instead of every playlist group

Compact media cards instead of full metadata records

Pre-ranked backup streams instead of all source health data

12.1 Remote View Model
Example:

{
  "viewType": "search_results",
  "query": "India cricket",
  "items": [
    {
      "mediaId": "match-01",
      "title": "India vs Australia",
      "subtitle": "Live",
      "thumbnailUrl": "cached-thumb-ref",
      "playable": true
    }
  ],
  "expiresAt": 1783915200000
}
Remote views should be small, cacheable and replaceable.

13. Navigation Architecture by Product Profile
13.1 Full Television Navigation
Possible top-level sections:

Home

Live

Movies

Series

Sports

Guide

Library

Search

Recordings

Settings

13.2 Lite Receiver Navigation
Recommended top-level sections:

Home

Live

Favorites

Recent

Search

Settings

13.3 Embedded Receiver Navigation
Recommended top-level sections:

Now Playing

Pair Device

Recent Sessions

Settings

A constrained edition must not expose empty sections for unavailable features.

14. UI Component Tiers
The design system should offer component variants by device class.

14.1 Rich Components
Used on capable devices:

Animated media shelves

Large hero artwork

Contextual backgrounds

Rich metadata panels

Multi-layer focus effects

Video previews

14.2 Standard Components
Used on moderate devices:

Static hero

Limited animation

Medium artwork

Simplified metadata

Basic focus elevation

14.3 Lightweight Components
Used on legacy devices:

Compact cards

Static backgrounds

Small image sets

Border-based focus

Minimal transitions

Text-first errors

No background video

The same design tokens should preserve brand consistency across all tiers.

15. Data Ownership
Each data category must define its preferred owner.

Data	Full TV	Lite TV	Mobile/Desktop
Full playlist index	Local	Optional or remote	Local
Full EPG	Local	Remote/compact	Local
Favorites	Local + sync	Local + sync	Local + sync
Playback progress	Local + sync	Local + sync	Local + sync
AI embeddings	Optional	No	Preferred
Stream-health history	Limited	Minimal	Preferred
Artwork originals	Optional	No	Preferred
Compact thumbnails	Yes	Yes	Yes
Provider credentials	Optional	Restricted	Preferred
16. Legacy Application Modes
A legacy build may operate in one of several modes.

16.1 Standalone Lite Mode
The device stores:

One or more playlists

Favorites

Recent media

Compact EPG

Basic search data

Suitable for moderately constrained devices.

16.2 Companion-Assisted Mode
The device relies on a phone or desktop for:

Search

Playlist management

AI

Full EPG

Metadata enrichment

The television retains standalone favorites and recent playback.

16.3 Receiver-Only Mode
The device does not manage content sources.

It receives:

Playback tickets

Media references

Remote commands

Subtitle and audio selections

Suitable for extremely constrained hardware.

16.4 Home-Node-Assisted Mode
A desktop or home node supplies:

Media index

EPG

Search

Transcoding

Recording

Stream health

Source resolution

The television behaves as a thin receiver.

17. Feature Negotiation
Before performing a cross-device action, devices must negotiate capabilities.

Example handoff:

Phone wants to transfer 4K HEVC media
              ↓
TV reports maximum 1080p H.264
              ↓
Routing engine searches alternate source
              ↓
1080p H.264 source selected
              ↓
TV receives compatible playback ticket
If no compatible source exists:

Use a home-node transcoder where available.

Offer playback on the current device.

Explain the compatibility limitation clearly.

18. Version Compatibility
Different product profiles may update at different speeds.

The protocol must support:

Older receivers

Newer controllers

Newer receivers

Older controllers

Optional fields

Capability fallback

Protocol deprecation windows

18.1 Compatibility Rules
New fields must have safe defaults.

Unknown message fields must be ignored.

Required protocol changes must include a migration period.

Basic playback commands should remain stable for long periods.

Legacy receivers should receive extended protocol support where practical.

Security-critical protocol versions may be force-retired.

19. Module Lifecycle
Each module should define:

Initialization cost

Memory budget

Storage budget

Permissions

Background tasks

Shutdown behavior

Supported profiles

Required capabilities

Feature flags

Failure behavior

Example:

module: full_epg
supported_profiles:
  - full_tv
  - standard_tv
memory_budget_mb: 80
storage_budget_mb: 250
background_jobs:
  - epg_refresh
dependencies:
  - media_database
  - timezone_service
fallback: compact_epg
20. Permission Minimization
Each product build should request only the permissions it needs.

A receiver-only build should not request:

Broad file access

Microphone

Camera

Recording permissions

Background-download permissions

Media library access

unless those features are explicitly included.

This improves:

User trust

Store compliance

Security

Setup simplicity

Legacy operating-system compatibility

21. Binary and Dependency Isolation
Heavy native components should be separated into optional packages or product-specific builds.

Examples:

AI runtime

FFmpeg processing tools

Transcoding libraries

Recording modules

Full subtitle engine

Advanced codec packs

Analytics SDKs

Cloud storage integrations

A lite receiver should not contain inactive libraries solely because the full app uses them.

22. Release Channels
Airo TV may maintain separate release channels:

Full TV stable

Lite TV stable

Receiver stable

Legacy experimental

Vendor-specific

Internal certification

Each channel may have:

Independent version numbers

Independent device eligibility

Separate rollout percentages

Separate crash thresholds

Different update cadence

Different feature flags

Shared protocol compatibility must be preserved.

23. Store Listing Strategy
Separate product profiles may be distributed through:

Option A — Single Adaptive Application
Advantages:

One listing

Shared ratings

Simpler account experience

Automatic runtime adaptation

Disadvantages:

Larger binary

More dependencies

Greater testing complexity

Harder support for very old APIs

Unnecessary permissions or libraries

Option B — Full and Lite Applications
Advantages:

Smaller legacy build

Clear hardware targeting

Reduced dependency footprint

Better performance tuning

Easier store filtering

Disadvantages:

Multiple listings

User confusion risk

Separate reviews

More release management

Option C — One Store Listing with Device-Targeted Delivery
Where supported, use:

Android App Bundles

ABI splits

Feature modules

Device catalog exclusions

Conditional delivery

The final strategy should be selected after validating store capabilities and dependency constraints.

24. Recommended Packaging Strategy
Initial recommendation:

Airo TV
For:

Modern and standard Android TV devices

Full-feature experience

Airo TV Lite
For:

Android 8 and Android 9

Low-memory devices

Older Fire TV hardware

Receiver-focused use cases

Airo Receiver
For:

Operator devices

Embedded deployments

Very constrained hardware

Managed installations

All three should connect to the same account and device ecosystem.

25. User Account Experience
Users should not need separate subscriptions for each edition.

One account should support:

Full app on modern TV

Lite app on old TV

Mobile companion

Desktop app

Receiver client

Entitlements should be based on:

Subscription

Household limits

Feature access

Device trust

not on which edition is installed.

26. Upgrade and Migration
26.1 Lite to Full Upgrade
When a user replaces an old device:

Trusted-device relationships should migrate.

Favorites should sync.

Playback progress should sync.

Profiles should sync.

Playlist access should be restored securely.

Device names should be preserved where practical.

26.2 Full to Lite Downgrade
When performance issues occur, the user may switch to Lite Mode or install the Lite edition.

The migration should preserve:

Account

Favorites

Recent items

Progress

Device pairing

Essential settings

Unsupported features should be disabled without corrupting their cloud state.

27. Reliability Boundaries
Every profile must define what it guarantees.

Lite Receiver Guarantees
Pairing

H.264 playback where hardware supports it

D-pad navigation

Phone remote

Favorites

Recent playback

Compact EPG

Playback recovery

Session synchronization

It does not guarantee:

4K

HEVC

HDR

Multi-view

Recording

Local AI

Full offline catalog

Advanced animation

Large local downloads

28. Testing Strategy
28.1 Module Tests
Each module must pass:

Standalone unit tests

Dependency validation

Initialization and shutdown tests

Memory-budget tests

Error-fallback tests

Profile compatibility tests

28.2 Product Composition Tests
Every build profile must verify:

Only approved modules are included.

Unsupported navigation entries are absent.

Unused permissions are absent.

Native libraries match the profile.

Feature declarations match actual capabilities.

Protocol capability announcements are accurate.

28.3 Cross-Profile Tests
Test:

Full mobile to Lite TV

Full mobile to receiver-only TV

Full TV to Lite TV handoff

New controller to old receiver

Old controller to new receiver

Cloud outage

Companion unavailable

Unsupported media transfer

Feature delegation failure

29. Performance Budgets by Product Profile
Resource	Full TV	Standard TV	Lite Receiver	Embedded Receiver
App startup target	<3 sec	<4 sec	<5 sec	<4 sec
UI memory budget	High	Moderate	Low	Minimal
Artwork cache	Large	Medium	Small	Minimal
EPG storage	Extended	Limited	Compact	Remote
Local search index	Full	Partial	Basic	None
Concurrent decoders	Hardware based	1–2	1	1
Background jobs	Full	Reduced	Minimal	Essential only
AI runtime	Optional	Remote preferred	None	None
Exact budgets should be defined through device benchmarking.

30. Acceptance Criteria
The modular product platform is production-ready when:

A lightweight receiver build can be produced without AI, recording or full EPG dependencies.

The Lite build shares the same session and playback protocols as the full application.

Unsupported features are excluded from navigation.

Feature availability is accurately published through device capabilities.

A controller can delegate search and EPG operations to another node.

A Lite receiver remains useful when its companion device is unavailable.

Receiver-only mode can play authorized media without maintaining a full catalog.

Product profiles request only required permissions.

Heavy native libraries can be excluded from constrained builds.

Full and Lite applications can use the same user account and subscription.

Favorites and playback progress synchronize across product profiles.

A legacy receiver can reject unsupported handoffs before current playback stops.

Protocol compatibility tests cover mismatched client versions.

Module dependency validation prevents invalid builds.

Each product profile has a declared resource budget.

Runtime feature flags cannot expose modules absent from the build.

Security-critical updates can be delivered independently to legacy editions.

The platform can retire one product profile without disrupting the rest of the ecosystem.

Device capability determines the experience rather than Android version alone.

Users receive a coherent Airo TV experience across full, lite and receiver applications.

31. Recommended Engineering Structure
packages/
├── core_identity
├── core_security
├── core_protocol
├── core_sessions
├── core_media_models
├── playback_contract
├── playback_android
├── playback_desktop
├── feature_pairing
├── feature_remote
├── feature_compact_epg
├── feature_full_epg
├── feature_basic_search
├── feature_advanced_search
├── feature_ai
├── feature_recording
├── feature_multiview
├── feature_profiles
├── feature_diagnostics
├── product_capabilities
└── design_system

apps/
├── airo_mobile
├── airo_tv_full
├── airo_tv_lite
├── airo_receiver
├── airo_desktop
└── airo_home_node
Dependency direction must always move from product applications toward feature modules and then toward shared core contracts.

Core modules must never import full product applications.

32. Product Principles
Compose Products, Do Not Disable Screens
Legacy support should be achieved through deliberate application composition.

The Smallest Useful Experience Wins
A stable receiver with six excellent features is better than a full app with thirty unreliable features.

Shared Protocol, Different Product
Devices may run different Airo editions while remaining part of one ecosystem.

Delegate Instead of Duplicate
Constrained devices should ask capable devices to perform expensive work.

Build-Time Simplicity, Runtime Adaptability
Remove fundamentally unnecessary modules at build time and adapt remaining features at runtime.

Companion Enhanced, Not Permanently Dependent
Legacy televisions should benefit from companions without becoming unusable when they are unavailable.

One Account, Many Device Roles
Users should not have to understand which internal product profile a device uses.

Maintainability Is a Feature
Modularity should reduce the cost of supporting old devices rather than multiply conditional logic throughout the codebase.

33. Expected Outcome
Airo TV can support old and constrained televisions without weakening the architecture of the primary application.

A modern television can run the full product.

An older Android TV can run Airo TV Lite.

An extremely constrained box can run Airo Receiver.

A phone or desktop can provide search, AI, EPG and metadata services.

All devices still share:

Identity

Playback sessions

Remote control

Trusted-device relationships

Favorites

Progress

Security

Cloud continuity

Local communication

This lets Airo TV expand device reach while preserving a premium, reliable experience tailored to what each device can usefully perform.


Yes, you can absolutely collect comprehensive user analytics from Airo TV across all platforms using Google services.
Because you are using Flutter, you can implement a single analytics framework that tracks user actions on iPhones, Android phones, tablets, laptops, and older Android TVs (like Android 8/9). [1] 
The industry standard for this is Google Analytics for Firebase, which connects seamlessly with Flutter.
------------------------------
## 📊 What Google Analytics Can Track for Airo TV
By implementing Google Analytics, you can gather high-value insights to improve your product and marketing: [2, 3, 4] 

* Platform Tracking: See exactly what percentage of your users stream on Older Android TVs vs. iPhones vs. Laptops.
* Media Engagement: Track metrics like average watch time, which live TV channels are most popular, or how often users stream VOD movies.
* Feature Adoption: Measure how many users actually use your On-Device LLM Voice Search or the Mobile-to-TV Cast feature.
* Error & Quality Logging: Log when a stream buffers too long or fails completely, helping you remove dead IPTV links automatically. [5] 

------------------------------
## 🛠️ The Tech Stack Setup (Flutter + Firebase)
Google officially maintains the firebase_analytics plugin for Flutter. It natively supports iOS, Android, macOS, and Web/Windows (via web builds).
## Step 1: Add Dependencies
Add the core Firebase packages to your pubspec.yaml file:

dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.0.0      # Core Firebase engine
  firebase_analytics: ^11.0.0 # Google Analytics engine

## Step 2: Initialize Firebase in Flutter
Initialize Firebase inside your main.dart before the UI renders:

import 'package:flutter/material.dart';import 'package:firebase_core/firebase_core.dart';import 'package:firebase_analytics/firebase_analytics.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase for the specific platform (iOS/Android/TV)
  await Firebase.initializeApp();
  
  runApp(const AiroTVApp());
}

------------------------------
## 💻 Implementation Code: Logging Custom IPTV Events
Do not just track basic page views. To understand your business use cases, you must log custom semantic events specific to streaming.
Create a dedicated AnalyticsService class to handle this cleanly across your app:

import 'package:firebase_analytics/firebase_analytics.dart';
class AiroTVAnalytics {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // 1. Track when a user plays a stream
  static Future<void> logMediaPlayback({
    required String mediaTitle,
    required String streamType, // "LIVE_TV", "VOD", "CATCH_UP"
    required String sourcePlatform, // "Local_M3U", "Xtream"
  }) async {
    await _analytics.logEvent(
      name: 'media_playback_started',
      parameters: {
        'media_title': mediaTitle,
        'stream_type': streamType,
        'source_platform': sourcePlatform,
      },
    );
  }

  // 2. Track On-Device LLM AI Voice Usage
  static Future<void> logAiVoiceSearch({required String userQuery, required bool wasSuccessful}) async {
    await _analytics.logEvent(
      name: 'ai_voice_search',
      parameters: {
        'query_length': userQuery.length,
        'success': wasSuccessful ? 1 : 0,
      },
    );
  }

  // 3. Track Mobile-to-TV Handoff (Casting)
  static Future<void> logDeviceCast({required String targetDeviceType}) async {
    await _analytics.logEvent(
      name: 'mobile_to_tv_cast',
      parameters: {
        'target_device': targetDeviceType, // e.g., "Android_8_TV", "FireTV_Stick"
      },
    );
  }
}

------------------------------
## ⚠️ Critical Considerations for Older Smart TVs (Android 8/9)
When running Google Analytics on low-memory, legacy TV devices, you must tweak your setup to prevent performance slowdowns:

   1. Turn Off Automatic Screen Tracking: Firebase automatically tracks every time a screen changes, which causes unnecessary CPU overhead on slow TV chips. Turn off automatic tracking in your config and log screen changes manually only when essential.
   2. Enable Data Batching: Firebase handles this natively, but ensure you do not force instant event uploads. Let Firebase batch events in the background and upload them every few minutes so it does not interrupt active video decoding. [6] 
   3. Google Play Services Dependency: Ensure your Android configurations don't strictly require the absolute newest version of Google Play Services, as older Android TVs might not have updated background system frameworks. Firebase Analytics degrades gracefully and will still collect data safely.

------------------------------
## 🔒 Privacy and App Store Compliance
Since Airo TV is positioned as a privacy-first premium hub, you must handle analytics transparently to pass Apple App Store and Google Play Store reviews:

* Anonymize IP Addresses: Google Analytics 4 (GA4) anonymizes IP addresses by default.
* Never Track Personal Stream Links: Do not send the actual username, password, or exact tokenized URL of the user's private IPTV playlist to Google. Only log generic metadata like the channel name ("Sky Sports News") or category ("Sports").
* User Opt-Out: Add a simple toggle button in your Airo TV settings page letting privacy-conscious users completely turn off analytics collection (_analytics.setAnalyticsCollectionEnabled(false)).

How would you like to structure your initial dashboard data? If you'd like, I can show you how to link Firebase Crashlytics alongside Analytics so you can automatically get alerts whenever an older TV crashes due to out-of-memory constraints.

[1] [https://hisense.sg](https://hisense.sg/google-tv-vs-android-tv-8/)
[2] [https://nav43.com](https://nav43.com/digital-marketing/google-analytics-experts/)
[3] [https://adswerve.com](https://adswerve.com/partners/google)
[4] [https://www.smartweb.eu](https://www.smartweb.eu/google-analytics/)
[5] [https://www.amagi.com](https://www.amagi.com/blog/power-your-ott-strategy-with-analytics)
[6] [https://www.bounteous.com](https://www.bounteous.com/insights/2020/04/01/reporting-google-analytics-google-analytics-4-properties/)

This becomes Volume 9, defining Airo TV’s analytics, experimentation, diagnostics, privacy controls, and legacy-device telemetry architecture.

Airo TV Product Requirements Document
Volume 9 — Product Analytics, Playback Quality Telemetry, Privacy and Experimentation
Document status: Draft
Version: 1.0
Primary objective: Build a unified, privacy-conscious analytics platform that measures product adoption, playback quality, device performance, reliability and subscription conversion across all Airo TV applications
Applicable products: Mobile, tablet, Full TV, Lite TV, Receiver, desktop and home node
Architecture model: Vendor-neutral analytics abstraction with optional Firebase-backed implementations

1. Purpose
This document defines how Airo TV should collect and use product analytics without compromising its privacy-first positioning.

Analytics should help the team understand:

Which platforms and device classes users rely on

Whether onboarding succeeds

Which product capabilities are adopted

Where playback fails

Which legacy devices experience resource problems

Whether mobile-to-TV handoff works reliably

Whether users understand the product

Which premium features influence conversion and retention

How application updates affect stability

Which modules should be optimized or removed

Analytics must not become a system for collecting private viewing behavior, provider credentials or user-owned playlist information.

2. Analytics Principles
2.1 Measure the Product, Not the User’s Private Media
Airo TV should measure:

Feature usage

Session success

Performance

Error categories

Device capabilities

Aggregate engagement

Airo TV should avoid collecting:

Raw playlist URLs

Provider usernames

Provider passwords

Authentication tokens

Local file paths

Spoken voice queries

Exact search text

Full channel names by default

Full movie or episode titles by default

Private NAS addresses

IP camera names

Viewing behavior tied to an identifiable person

2.2 Privacy by Default
Analytics should be designed around data minimization.

Every proposed event property must answer:

Is it necessary?

Can it be represented as a category rather than raw text?

Can it be processed locally?

Can it be aggregated before upload?

Does it reveal viewing interests?

Can it identify a media provider?

Can it identify a household device?

Is it required for reliability or merely interesting?

If the value is not needed for a defined product decision, it should not be collected.

2.3 Analytics Must Never Affect Playback
Analytics operations must not:

Delay player startup

Block UI rendering

Interrupt stream decoding

Increase buffering

Hold critical locks

Trigger large network uploads during playback

Cause application failure when the analytics provider is unavailable

All analytics calls must be asynchronous, buffered and non-blocking.

2.4 Vendor Independence
Application code must not call Firebase, Google Analytics or another external analytics SDK directly throughout feature modules.

A shared analytics contract should allow Airo TV to:

Use different providers by platform

Disable analytics in Lite builds

Replace vendors later

Route operational telemetry separately

Support local-only diagnostics

Respect regional privacy requirements

Run without Google Play Services

3. Analytics Architecture
Feature Module
      │
      ▼
Analytics Event Contract
      │
      ▼
Privacy Filter and Consent Gate
      │
      ▼
Event Buffer and Batching
      │
      ├── Product Analytics Provider
      ├── Reliability Telemetry Provider
      ├── Local Diagnostics Store
      └── Disabled / No-Op Provider
4. Analytics Service Contract
The shared application interface should resemble:

AnalyticsService
├── initialize()
├── identifyAnonymousInstallation()
├── setConsent()
├── logEvent()
├── logScreen()
├── setUserProperty()
├── beginTimedEvent()
├── endTimedEvent()
├── flush()
├── reset()
└── setCollectionEnabled()
Feature modules must submit typed events rather than arbitrary maps.

4.1 Typed Event Example
sealed class AiroAnalyticsEvent {
  const AiroAnalyticsEvent();
}

final class PlaybackStartedEvent extends AiroAnalyticsEvent {
  const PlaybackStartedEvent({
    required this.contentType,
    required this.sourceType,
    required this.receiverProfile,
    required this.startupTimeBucket,
  });

  final ContentType contentType;
  final SourceType sourceType;
  final ProductProfile receiverProfile;
  final StartupTimeBucket startupTimeBucket;
}
Typed events reduce accidental transmission of sensitive data.

5. Analytics Domains
Airo TV analytics should be separated into distinct domains.

5.1 Acquisition Analytics
Measures:

Installation source

Referral campaign

Store platform

First application launch

Region at coarse country level where permitted

First subscription screen impression

Trial start

Subscription conversion

5.2 Onboarding Analytics
Measures:

Onboarding started

Permission request displayed

Permission granted or denied

Playlist setup method selected

QR pairing started

QR pairing completed

Provider validation result

First channel loaded

First successful playback

Time to first successful playback

5.3 Product Usage Analytics
Measures:

Home opened

Live section opened

Guide opened

Search invoked

Favorite added

Profile switched

Phone remote opened

Device handoff requested

AI feature invoked

Catch-up summary requested

Stream failover activated

Settings changed

5.4 Playback Quality Analytics
Measures:

Playback request

Playback start success

Startup latency

Buffering count

Buffering duration

Reconnect count

Source failover count

Playback error category

Playback end reason

Hardware decoder used

Software fallback used

Average bitrate bucket

Resolution bucket

5.5 Device Ecosystem Analytics
Measures:

Product profile

Operating-system family

Android API bucket

Device capability tier

Receiver type

Local versus cloud command route

Device discovery success

Pairing success

Handoff success

Delegated task success

Companion availability

5.6 Subscription Analytics
Measures:

Paywall viewed

Plan selected

Trial started

Purchase completed

Purchase failed

Subscription restored

Renewal state

Cancellation flow opened

Premium feature gate encountered

Premium feature activated after purchase

Payment events must not include full billing details.

5.7 Reliability Analytics
Measures:

Application crash

Application not responding

Out-of-memory event

Player crash

Database migration failure

EPG import failure

Local discovery failure

Protocol mismatch

Background-service termination

Storage exhaustion

Native decoder failure

Reliability telemetry should be logically separate from marketing analytics.

6. Event Taxonomy
All events should follow a stable naming convention.

Recommended pattern:

domain_object_action
Examples:

onboarding_started

playlist_import_completed

pairing_completed

playback_started

playback_failed

stream_failover_completed

remote_command_completed

handoff_completed

ai_search_completed

subscription_started

6.1 Event Naming Rules
Use lowercase snake case.

Use past tense for completed outcomes.

Avoid provider-specific names.

Avoid raw content titles.

Avoid user-generated text.

Keep event names stable after release.

Use versioned schemas for breaking changes.

Do not encode values inside event names.

Do not create one event name per media category.

7. Common Event Envelope
Every event should include a small standard metadata envelope.

{
  "eventName": "playback_started",
  "schemaVersion": 2,
  "occurredAt": 1783915200000,
  "installationId": "anonymous-installation-id",
  "sessionId": "analytics-session-id",
  "platform": "android_tv",
  "productProfile": "lite_receiver",
  "appVersion": "1.8.0",
  "deviceTier": "legacy_optimized",
  "consentMode": "product_analytics",
  "parameters": {}
}
7.1 Installation Identifier
Use a randomly generated installation identifier rather than:

Advertising ID

Hardware serial

MAC address

Android ID without justification

Device fingerprint

The identifier must be reset when:

The user requests analytics reset

The user deletes the account where applicable

The application is reinstalled, unless platform behavior prevents this

Privacy policy requires rotation

8. Playback Event Model
8.1 Playback Requested
{
  "eventName": "playback_requested",
  "parameters": {
    "contentType": "live",
    "sourceType": "xtream",
    "receiverType": "android_tv",
    "routeType": "direct_cloud",
    "qualityPreference": "auto"
  }
}
8.2 Playback Started
{
  "eventName": "playback_started",
  "parameters": {
    "contentType": "vod",
    "sourceType": "local_nas",
    "decoderType": "hardware",
    "resolutionBucket": "1080p",
    "startupTimeBucket": "1_to_3_seconds"
  }
}
8.3 Playback Failed
{
  "eventName": "playback_failed",
  "parameters": {
    "phase": "startup",
    "errorCategory": "decoder",
    "retryable": true,
    "fallbackAttempted": true,
    "deviceTier": "legacy_optimized"
  }
}
8.4 Playback Completed
{
  "eventName": "playback_session_ended",
  "parameters": {
    "contentType": "vod",
    "durationBucket": "30_to_90_minutes",
    "completionBucket": "75_to_100_percent",
    "endReason": "user_stopped",
    "bufferingBucket": "under_10_seconds"
  }
}
9. Media Privacy Classification
Media-related values must be classified before collection.

9.1 Safe Aggregate Metadata
Generally acceptable:

Live, VOD, series, local file

Sports, news, movie, kids as broad category

Resolution bucket

Codec family

Language code where appropriate

Session duration bucket

Completion percentage bucket

Source protocol type

Device class

9.2 Restricted Metadata
Collect only with strong justification and appropriate consent:

Exact channel name

Exact movie title

Exact program title

Exact search term

Exact team or league

Exact playlist name

Detailed viewing timestamp history

Profile name

Local server name

9.3 Prohibited Analytics Data
Never send:

Stream URLs

Signed URLs

M3U URLs

Xtream credentials

Authentication headers

Cookies

Local network addresses

File-system paths

Voice recordings

Raw voice transcripts

Camera feed identifiers

Private playlist contents

10. AI Analytics
AI analytics should evaluate quality without collecting the user’s natural-language query.

10.1 Allowed AI Metrics
AI feature invoked

Processing location

Model class

Inference duration bucket

Intent category

Confidence bucket

Number of results

Result selected

Command completed

Fallback used

User corrected result

AI task cancelled

10.2 Example
{
  "eventName": "ai_search_completed",
  "parameters": {
    "intentCategory": "find_live_sports",
    "processingLocation": "companion_device",
    "latencyBucket": "under_1_second",
    "confidenceBucket": "high",
    "resultCountBucket": "1_to_5",
    "selectionMade": true
  }
}
The raw query must remain local unless the user has explicitly enabled a cloud AI service requiring it.

11. Device Pairing and Handoff Analytics
11.1 Pairing Events
pairing_started

pairing_code_displayed

pairing_completed

pairing_failed

device_revoked

Parameters may include:

Pairing method

Controller type

Receiver type

Local or cloud path

Completion time bucket

Failure category

11.2 Handoff Events
handoff_requested

handoff_prepared

handoff_completed

handoff_aborted

handoff_failed

Parameters may include:

Source device class

Destination device class

Media type

Route type

Preparation duration bucket

Position variance bucket

Failure category

Do not include media title or source URL.

12. Legacy Device Analytics
Legacy-device telemetry should focus on reliability and optimization.

12.1 Device Properties
Collect coarse values:

Android API bucket

Architecture

RAM class

Storage class

Device capability tier

Hardware-decoder availability

Maximum tested resolution

Product profile

Low-memory mode enabled

Avoid collecting unique hardware identifiers.

12.2 Legacy Events
legacy_mode_enabled

memory_pressure_detected

low_storage_detected

decoder_fallback_used

artwork_cache_reduced

background_job_deferred

remote_search_delegated

epg_processing_delegated

unsupported_feature_hidden

12.3 Optimization Decisions
Analytics should reveal whether automatic adaptations improve outcomes.

Example:

{
  "eventName": "performance_profile_applied",
  "parameters": {
    "profile": "lite_receiver",
    "reason": "low_memory",
    "previousCrashDetected": false,
    "playbackContinued": true
  }
}
13. Analytics Profiles by Product Edition
13.1 Full TV
May collect:

Product analytics

Playback quality

Feature usage

Subscription events

Reliability telemetry

13.2 Lite Receiver
Should collect a reduced set:

Startup

Pairing

Playback quality

Decoder behavior

Memory pressure

Remote-command reliability

Critical crashes

Avoid:

Automatic screen tracking

High-frequency UI events

Detailed browsing events

Excessive heartbeat telemetry

13.3 Embedded Receiver
Collect only:

Activation success

Playback success

Error categories

Command latency

Device health

Software version

Update success

13.4 Local-Only Mode
In local-only mode:

External analytics should be disabled.

Essential diagnostics may remain locally stored.

Crash reports should not upload without permission.

Users may export a redacted support bundle manually.

14. Consent Model
Airo TV should separate categories of collection.

14.1 Required Operational Data
May include data strictly necessary for:

Account authentication

Subscription validation

Security

Fraud prevention

Device registration

Service operation

This is not the same as optional product analytics.

14.2 Optional Product Analytics
May include:

Feature adoption

Navigation

Onboarding funnel

Aggregate playback engagement

Performance measurements

14.3 Optional Crash Reporting
May include:

Stack traces

Device class

App version

Memory status

Native crash information

All sensitive values must be redacted.

14.4 Optional Personalized Analytics
Airo TV should avoid this category initially.

It may later include:

Cross-device recommendations

Personalized engagement analysis

Long-term viewing preferences

This requires separate, explicit consent and stronger privacy controls.

15. Privacy Controls
Users should be able to control:

Product analytics

Crash reporting

Personalized recommendations

Viewing history synchronization

AI cloud processing

Diagnostic uploads

Settings should clearly explain:

What is collected

Why it is collected

Whether it leaves the device

How to disable it

What features may be affected

15.1 Reset Analytics Data
Users should be able to:

Disable analytics

Reset the anonymous installation identifier

Clear local diagnostic history

Request deletion of account-linked analytics where applicable

Export privacy settings

16. Screen Tracking
16.1 Manual Screen Tracking
Airo TV should prefer manual screen events.

Reasons:

TV navigation differs from mobile navigation.

Automatic route names may be technically meaningless.

Legacy devices should minimize unnecessary events.

Product profiles may use different layouts.

Some screens contain sensitive context.

16.2 Screen Event Example
{
  "eventName": "screen_viewed",
  "parameters": {
    "screenName": "compact_guide",
    "productProfile": "lite_receiver",
    "entryPoint": "home"
  }
}
Avoid dynamic screen names containing content titles.

17. Event Batching and Offline Queue
17.1 Queue Requirements
The analytics layer must:

Buffer events locally.

Batch uploads.

Persist important events across restart.

Cap queue size.

Drop low-priority events first.

Retry with backoff.

Respect metered-network preferences.

Stop collection immediately when disabled.

Delete queued optional events after consent withdrawal.

17.2 Event Priorities
Critical
Security event

Purchase completion

Severe crash marker

Database corruption

Device revocation

High
Playback failure

Handoff failure

Pairing failure

Subscription failure

Out-of-memory event

Normal
Feature usage

Playback start

Search completion

Settings changes

Low
Screen view

Focus interaction

Minor UI timing

Background refresh

Legacy devices should retain only high-value events.

18. Upload Scheduling
Uploads should be deferred when:

Active playback is buffering.

The device is under memory pressure.

The device is overheating.

The network is metered.

Battery is low.

The application is in constrained receiver mode.

A recording is in progress.

A large playlist import is active.

Analytics flush should never be required before application shutdown.

19. Playback Quality Metrics
19.1 Core Quality Metrics
Track:

Time to first frame

Join failure rate

Rebuffer count

Rebuffer duration

Average playable bitrate

Decoder failure

Stream restart count

Failover success

Playback completion

Audio-only failure

Subtitle failure

19.2 Derived KPIs
Playback Start Success Rate
successful playback starts
──────────────────────────
total playback requests
Rebuffer Ratio
total buffering duration
────────────────────────
total playback duration
Failover Recovery Rate
successful source recoveries
────────────────────────────
all failover attempts
Time to First Frame
Measure from user playback request to first rendered frame.

20. Product Funnel Metrics
20.1 Activation Funnel
Install
  ↓
First launch
  ↓
Content source added
  ↓
First media result visible
  ↓
First successful playback
  ↓
Second playback session
  ↓
Companion paired
20.2 Premium Funnel
Premium feature discovered
          ↓
Paywall viewed
          ↓
Plan selected
          ↓
Trial started
          ↓
Premium feature used
          ↓
Renewal
20.3 Legacy Activation Funnel
Lite app installed
        ↓
Device profile detected
        ↓
Phone pairing offered
        ↓
Phone paired
        ↓
Playback handoff completed
        ↓
Repeat receiver session
21. Feature Adoption Metrics
Track adoption for:

Phone remote

Voice search

AI search

Automatic playlist cleanup

Compact EPG

Full EPG

Multi-view

Playback handoff

Cloud continuity

Stream failover

Catch-up summary

Parental controls

Local media streaming

Home node

For each feature, measure:

Eligible users

Exposure

First use

Successful use

Repeat use

Failure rate

Retention correlation

Eligibility must be included so unavailable features do not artificially reduce adoption rates.

22. User Properties
Only a small set of non-sensitive user or installation properties should be defined.

Potential properties:

Subscription tier

Product profile

Primary platform category

Device capability tier

Companion paired

Analytics consent state

Cloud sync enabled

Local-only mode

Onboarding completed

Avoid properties such as:

Favorite channel

Favorite team

Viewing genre profile

Political-content preference

Adult-content usage

Exact provider name

23. Crash Reporting
23.1 Crash Data
Crash telemetry may include:

App version

Platform

Product profile

Android API bucket

Device tier

Active module

Memory pressure

Playback engine state

Decoder family

Last non-sensitive application event

Stack trace

Native crash symbols

23.2 Crash Redaction
Before upload, redact:

Media URLs

Authorization headers

Provider domains where sensitive

Local file paths

Usernames

Device names

Search text

Media titles

Local IP addresses

Playlist names

23.3 Crash Correlation
The team should be able to identify:

Crashes by Android API

Crashes by device tier

Crashes by product profile

Crashes by playback backend

Crashes by codec

Out-of-memory clusters

Crashes after specific releases

Crashes during pairing or handoff

24. Analytics SDK Selection
Airo TV may use different providers for different purposes.

Possible categories:

Product analytics provider

Crash reporting provider

Performance monitoring provider

Internal operational telemetry

Self-hosted analytics

Local-only diagnostics

Firebase may be used where it is supported and appropriate, but the application architecture must not assume identical SDK availability across all platforms.

Desktop, embedded or non-Google devices may require:

Alternate SDK

REST-based event upload

Self-hosted event gateway

No-op analytics

Local diagnostics only

25. Google Services Integration
When Firebase-based analytics is enabled, it should be isolated inside an adapter.

AnalyticsService
        │
        ├── FirebaseAnalyticsAdapter
        ├── SelfHostedAnalyticsAdapter
        ├── LocalDiagnosticsAdapter
        └── NoOpAnalyticsAdapter
The Firebase adapter should:

Initialize only after consent where required.

Disable automatic collection where appropriate.

Use typed, approved event schemas.

Avoid automatic screen naming.

Avoid raw user text.

Respect collection-disable calls.

Fail silently without affecting application features.

Package versions must be managed through the dependency governance process rather than hardcoded indefinitely in the requirements document.

26. Self-Hosted Event Gateway
Airo TV may later operate its own event gateway.

Benefits:

Vendor independence

Stronger data minimization

Custom retention

Regional storage control

Better cross-platform consistency

Easier data deletion

Reduced dependency on Google Play Services

26.1 Gateway Responsibilities
Validate event schema

Reject prohibited fields

Apply rate limits

Remove identifiers

Enforce consent

Batch ingestion

Route events by category

Apply retention policy

Support deletion requests

27. Schema Registry
Every analytics event must have a registered schema.

Example:

event: playback_failed
version: 2
owner: playback_team
purpose: measure playback reliability
retention_days: 90
allowed_parameters:
  - phase
  - error_category
  - retryable
  - fallback_attempted
  - device_tier
prohibited_parameters:
  - media_url
  - media_title
  - playlist_name
  - provider_username
27.1 Schema Governance
Adding an event requires:

Product purpose

Data owner

Parameter list

Privacy review

Retention period

Dashboard requirement

Removal plan

Test coverage

Unknown event parameters should be rejected in development and stripped in production.

28. Retention Policy
Recommended categories:

Data category	Suggested retention
Raw product events	30–90 days
Aggregated product metrics	Longer, based on policy
Raw crash data	30–90 days
Security events	Based on legal and operational need
Anonymous performance aggregates	Up to 12 months
Voice or query text	Not collected by default
Direct media identifiers	Not collected by default
Retention must be documented and enforced technically.

29. Data Access Controls
Analytics data should be accessible only to authorized roles.

Suggested roles:

Product analytics

Playback reliability

Engineering operations

Security

Finance and subscription

Privacy administration

Access should be:

Least privilege

Audited

Revocable

Environment separated

Restricted for raw event exports

30. Experimentation Framework
30.1 Purpose
Airo TV may use controlled experiments to test:

Onboarding flows

Home layouts

Paywall presentation

Default playback settings

Legacy optimization thresholds

Recommendation trays

Feature education

30.2 Experiment Requirements
Stable anonymous assignment

Control group

Eligibility rules

Start and end dates

Primary metric

Guardrail metrics

Minimum sample threshold

Ability to stop remotely

No experiments on security controls

No deceptive subscription tests

30.3 Guardrail Metrics
Experiments must monitor:

Playback success

Crash rate

Buffering

Subscription refunds

Onboarding abandonment

Privacy opt-out rate

Legacy device memory pressure

Customer-support contacts

31. Remote Configuration
Remote configuration may control:

Rollout percentage

Feature education

Performance thresholds

Legacy mode triggers

Analytics sampling

Experiment allocation

Emergency feature disablement

Remote configuration must not:

Enable code absent from the build

Override consent

Weaken security

Enable unsupported codecs

Expose premium features without entitlement checks

Activate untested modules on legacy devices

32. Sampling
High-frequency events should be sampled.

Candidates:

Position heartbeat analytics

Focus movements

Network quality updates

Repeated buffer state

Screen impressions

Remote key presses

Never sample:

Purchase completion

Security events

Device revocation

Severe crash markers

Database corruption

Account deletion

33. Dashboards
33.1 Executive Dashboard
Show:

Active installations

Activated users

Subscription conversion

Retention

Playback success

Premium feature adoption

Platform distribution

Product-profile distribution

33.2 Playback Reliability Dashboard
Show:

Time to first frame

Playback failure rate

Rebuffer ratio

Failover rate

Failover success

Error categories

Decoder performance

Quality by device tier

Quality by application version

33.3 Legacy Device Dashboard
Show:

Android API distribution

Lite receiver activation

Memory-pressure rate

Out-of-memory crash rate

Decoder fallback frequency

Phone-assisted search usage

Compact EPG success

Long-session stability

Unsupported codec rate

33.4 Device Ecosystem Dashboard
Show:

Pairing completion

Discovery success

Local versus cloud commands

Handoff success

Average command latency

Companion-device usage

Session recovery

Cross-network control usage

33.5 Subscription Dashboard
Show:

Paywall exposure

Trial starts

Conversion

Renewal

Restore success

Feature-driven conversion

Platform conversion

Refund and cancellation indicators

34. Alerts
Create operational alerts for:

Playback failure spike

Crash spike

Out-of-memory increase

Pairing failure increase

Handoff failure increase

Subscription purchase failures

EPG import failures

Protocol mismatch increase

Specific release regression

Specific device-class instability

Alerts should use thresholds and anomaly detection rather than individual user events.

35. Analytics Testing
35.1 Unit Tests
Verify:

Event schema

Parameter redaction

Consent gating

Event priority

Queue behavior

Sampling

User-property restrictions

Reset behavior

35.2 Integration Tests
Verify:

Provider initialization

Offline queue

Upload retry

Analytics disabled mode

Crash-report opt-out

Legacy build behavior

Local-only mode

Account deletion

Provider outage

35.3 Privacy Tests
Automated tests should fail if payloads contain patterns resembling:

URLs

Authorization headers

Passwords

Local IP addresses

File paths

Playlist credentials

Raw queries

Media titles where prohibited

35.4 Event Validation Tools
Development builds should include an event inspector showing:

Event name

Schema version

Allowed fields

Redacted fields

Consent decision

Upload provider

Queue priority

Sensitive values must still remain hidden.

36. Performance Requirements
Operation	Requirement
Analytics event enqueue	Under 5 ms preferred
UI thread blocking	None
Playback startup dependency	None
Legacy event queue memory	Strictly bounded
Upload during buffering	Deferred
Provider initialization failure	Must not affect app startup
Consent disable response	Immediate
Queue deletion after opt-out	Immediate for optional events
Analytics SDK crash impact	Isolated from core playback
37. Delivery Phases
Phase 1 — Analytics Foundation
Deliver:

Shared analytics contract

Typed events

Consent state

No-op provider

Local event inspector

Privacy field validation

Initial onboarding and playback events

Exit criteria:

No feature module calls a vendor SDK directly.

Analytics can be disabled globally.

Prohibited fields are rejected.

Phase 2 — Product and Playback Analytics
Deliver:

Playback event model

Pairing and handoff metrics

Feature adoption events

Funnel tracking

Device-tier properties

Initial dashboards

Exit criteria:

The team can measure activation and playback success.

Media URLs and raw queries are absent from analytics payloads.

Phase 3 — Reliability Telemetry
Deliver:

Crash-reporting adapter

Native playback diagnostics

Memory-pressure reporting

Legacy device dashboard

Release regression alerts

Redacted support reports

Exit criteria:

Crashes can be grouped by product profile and decoder.

Sensitive source information is removed before upload.

Phase 4 — Experimentation
Deliver:

Experiment assignment

Remote configuration

Guardrail metrics

Experiment dashboards

Kill switch

Sampling controls

Exit criteria:

Experiments can be stopped remotely.

Legacy-device stability metrics act as guardrails.

Phase 5 — Privacy and Data Governance
Deliver:

Analytics schema registry

Retention enforcement

Data deletion workflow

Access controls

Consent audit

Regional policy configuration

Optional self-hosted event gateway

Exit criteria:

Every event has an owner, purpose and retention policy.

User opt-out is respected across every product profile.

38. Acceptance Criteria
The analytics platform is production-ready when:

All feature modules use the shared analytics abstraction.

Airo TV can operate normally with analytics disabled.

Playback does not depend on analytics initialization or upload.

Stream URLs, credentials and authentication headers are never collected.

Raw voice queries and search text are not collected by default.

Media engagement is represented through categories and buckets.

Product analytics and crash reporting have separate consent controls.

Optional events are deleted when consent is withdrawn.

Legacy builds use a reduced event set.

Event uploads are deferred during playback stress.

Event queues are bounded.

Device capability tiers are measurable without hardware fingerprinting.

Pairing and handoff success can be measured.

Playback startup, buffering and failover metrics are available.

Crashes can be analyzed by app version, product profile and decoder.

Analytics schemas are centrally registered.

Unknown or prohibited fields are rejected.

Users can reset their analytics identifier.

Local-only mode disables external analytics.

Provider failure cannot crash the application.

Experiment assignment does not override privacy or security controls.

Remote configuration cannot enable code missing from the build.

Dashboards distinguish eligible users from total users.

Retention policies are technically enforced.

Account deletion and privacy requests include applicable analytics data.

Analytics access follows least-privilege rules.

Every event maps to a documented product or operational decision.

39. Important Corrections and Constraints
Exact Channel Names Should Not Be Collected by Default
Viewing a particular channel, program, news source, religious service, adult category or political broadcast may reveal sensitive interests.

Airo TV should prefer broad categories and anonymous quality metrics.

Firebase Is an Implementation, Not the Architecture
Firebase may be useful on supported platforms, but Airo TV must retain a vendor-neutral analytics layer for desktop, Fire OS, embedded builds and future platform changes.

Automatic Screen Tracking Is Often Low Value
TV applications use focus-driven navigation, overlays and playback surfaces that may not map cleanly to mobile route tracking.

Manual semantic events produce better product insights.

Analytics Cannot Remove Dead Provider Links Globally
Airo TV can use local health data to deprioritize bad streams in the user’s own sources.

It should not upload private playlist URLs to a central analytics platform to create a shared blacklist.

Crash Telemetry Requires Redaction
Native playback failures may include full URLs or file paths in exception text. These values must be sanitized before upload.

Low Analytics Overhead Still Requires Measurement
Even batched analytics SDKs consume memory, storage and network resources. Lite and embedded builds should be benchmarked with analytics enabled and disabled.

40. Product Principles
Measure Outcomes
Track whether playback, pairing and premium features succeed—not every possible interaction.

Minimize Media Data
Viewing behavior should be collected only at the level required for product improvement.

Privacy Is Part of the Premium Offering
Users should be able to understand and control analytics without losing basic playback.

Reliability Telemetry Is More Valuable Than Surveillance
Playback quality, crashes and latency are more actionable than exact content titles.

Analytics Must Be Replaceable
The product should not be permanently coupled to one vendor.

Legacy Devices Need Reduced Telemetry
Constrained hardware should prioritize playback over analytics richness.

Consent Must Be Enforced Technically
A settings toggle is insufficient unless collection, queuing and uploads actually stop.

41. Expected Outcome
Airo TV gains a reliable measurement system capable of answering:

Are users completing setup?

Which device profiles are stable?

Does phone-to-TV handoff work?

Are older televisions benefiting from Lite Receiver Mode?

Which playback engines and codecs fail?

Are premium features used after purchase?

Where do users abandon onboarding?

Are new releases improving or harming playback quality?

At the same time, Airo TV preserves its privacy-first positioning by refusing to collect raw playlists, credentials, URLs, voice queries or detailed viewing histories by default.

The resulting analytics system supports better engineering and business decisions without turning the media hub into a surveillance product.


