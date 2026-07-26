# Deterministic Search Engine v1

Issue: [#901](https://github.com/DevelopersCoffee/airo/issues/901)

## Contract

`searchPlaylistIndexV2` is the shared local Rust API for plain UI queries and
validated `IntentCommand` execution. It accepts optional text plus zero or more
structured filters. At least one of text or filters is required.

Indexed fields are:

- title;
- aliases (`tvg-name` and `tvg-id`);
- genre (`group-title`);
- language;
- country;
- provider; and
- tags.

Actor remains reserved for the Media Graph work in #882.

Filters support exact, prefix, and contains operators with AND semantics.
Unknown enum values cannot cross the generated FRB boundary, and empty values
are rejected before SQLite execution.

## Ranking

Ranking is stable and deterministic:

1. exact title;
2. title prefix;
3. exact alias;
4. alias prefix;
5. exact metadata field;
6. metadata prefix; and
7. bounded typo fallback.

Source position is the final tie-break. Indexed exact/prefix candidate unions
avoid scanning all 100,000 rows for normal text queries. Typo matching runs
only when deterministic candidates are empty, narrows candidates by a
three-character prefix, caps the candidate set at 10,000, and applies a
bounded Levenshtein distance in Rust.

## Refresh and storage

Playlist metadata is retained by the streaming mmap parser and written to the
version-2 binary cache and SQLite schema. Source size and modification time
remain the refresh fingerprint. Changed sources atomically rebuild; unchanged
sources warm-open; missing indexes rebuild from the mapped binary cache.

No playlist-sized parsing, filtering, or ranking runs on Dart's main isolate.

## Qualification

The aggregate benchmark alternates exact-title and selective structured-filter
queries over a deterministic 100,000-channel fixture. It records 30 measured
iterations after warm-up and reports p50/p95 latency without channel names,
paths, or URLs.

The v0.0.5 gate is search p95 below 10,000 microseconds on a named physical Fire
TV. Host measurements are regression evidence only.
