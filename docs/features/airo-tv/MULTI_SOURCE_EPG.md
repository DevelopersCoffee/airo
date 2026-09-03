# Multi-source EPG merge

`platform_epg` owns the reusable merge and refresh boundary. Aika Stream consumes
only bounded `CompactEpgWindow` values and does not parse XMLTV in presentation
code.

## Zero-config system guide

TV release builds can register the pipeline guide without user interaction:

- `IPTV_DATA_PLAYLIST_URL` identifies the bundled playlist.
- `IPTV_DATA_MANIFEST_URL` is the HTTPS `manifest.json` beside that playlist.
- `IPTV_DATA_COUNTRY` selects `guide_XX.xml.gz` and defaults to `IN`.

The system source is activated only while the configured playlist exactly
matches the bundled URL. The manifest filename must remain same-origin and its
SHA-256 must match before the parsed repository is swapped. Gzip decoding runs
off the main isolate. Existing user XMLTV configuration migrates into the
ordered source store and remains higher priority than the system source.

## Source contract

Each `EpgSourceWindow` contains an opaque, redacted source ID, a stable
priority, a revision, and compact programmes for one changed time window.
Lower priority numbers win. Equal-priority sources are ordered by source ID,
and programmes by start time and programme ID, so the same input always
produces the same result. Raw URLs, local paths, private addresses, and
credential-like values are rejected as source IDs.

The merger removes duplicate programme IDs and equivalent normalized
title/start/end listings. A higher-priority overlapping programme wins;
lower-priority programmes may fill uncovered time. Returned timestamps are
UTC.

## Incremental refresh

Fetchers and parsers must run on the platform worker/native boundary before
calling `IncrementalMultiSourceEpgRepository.applyRefresh`. A changed revision
replaces only programmes intersecting the supplied source window for channels
listed in `refreshedChannelIds` (inferred from entries by default). The explicit
list lets an empty refresh clear stale data. Other channels and time ranges
remain cached. Reusing the same revision is a no-op, and removing a source
updates the next query immediately.

## Missing guide time

Every channel supplied by at least one source reports uncovered time as
`CompactEpgGap`. A gap is metadata, never a programme: playback, reminders,
and details must not treat it as content. A policy may label short gaps as
adjacent to the preceding programme, but it never extends that programme.
Aika Stream renders gaps as non-focusable “No listing” blocks.
