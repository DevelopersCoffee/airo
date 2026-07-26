# Playlist Engine v2

Playlist Engine v2 is the native, local-only large-playlist boundary introduced
for milestone issue
[#900](https://github.com/DevelopersCoffee/airo/issues/900). It extends the
existing #814 Rust parser without changing its public APIs.

## Runtime contract

1. Dart downloads an authorized source to an app-private file.
2. `openPlaylistIndexNative` passes only absolute source/cache paths and a
   bounded first-page size across FRB.
3. Rust maps the source read-only and parses lines incrementally. It never
   allocates a playlist-sized source `String` or channel `Vec`.
4. A versioned binary cache and SQLite index are built as sibling temporary
   files and promoted only after both complete.
5. The first SQLite page returns immediately after open. Subsequent page/search
   calls use the opaque index path and return at most 500 channels.
6. A matching source size/modification fingerprint warm-opens the mapped binary
   cache and index. A missing/corrupt index rebuilds from the binary cache
   without reparsing M3U. A stale/corrupt cache rebuilds from the source.

The app must use `IndexedM3uPlaylistService` from
`platform_playlist_import`; presentation code must not parse, decode, or page
playlist files itself.

## Cache and schema versions

- Binary magic: `AIROPLV2`
- Binary format version: `2`
- SQLite schema version: `2`
- Binary file: `playlist-v2.cache`
- SQLite file: `playlist-v2.sqlite`

Unknown or stale versions rebuild instead of being deserialized. Derived files
contain user playlist metadata and therefore remain app-private and follow the
playlist cache deletion lifecycle. Logs and benchmark reports never include
source paths, stream URLs, channel names, or credentials.

## Memory ceiling

The v0.0.5 qualification ceiling is a 96 MiB RSS delta for a deterministic
100,000-channel fixture. The implementation bounds transient memory with:

- a read-only source mmap rather than a full source `String`;
- a 1 MiB binary-cache writer buffer;
- transactional SQLite inserts without a playlist-sized Dart/Rust channel
  collection;
- pages limited to 500 channels, with 50 as the default;
- SQLite temporary storage scoped to index construction.

An mmap can still contribute resident pages as the OS faults data in, so only
the benchmark's measured RSS delta on a named physical Fire TV can prove the
ceiling. Host numbers are regression evidence, not release qualification.

## Qualification

Focused host checks:

```bash
cd rust
cargo test -p airo_core
cargo clippy -p airo_core --all-targets -- -D warnings

cd ../packages/platform_playlist_import
flutter test test/indexed_m3u_playlist_test.dart

cd ../platform_benchmarks
flutter test test/playlist_index_benchmark_test.dart
```

After building `core_native` at the loader path, run the 100k benchmark:

```bash
cd packages/platform_benchmarks
AIRO_RUN_PLAYLIST_INDEX_BENCHMARK=true \
AIRO_PLAYLIST_BENCHMARK_DEVICE="Fire TV Stick 4K Max (2nd gen)" \
AIRO_PLAYLIST_BENCHMARK_PHYSICAL=true \
flutter test test/playlist_index_native_acceptance_test.dart
```

Milestone acceptance is strict:

- exactly 100,000 indexed channels;
- cold open below 1,000,000 microseconds;
- warm open below 300,000 microseconds;
- deterministic search p95 below 10,000 microseconds;
- RSS delta at or below 96 MiB;
- cold status `coldBuilt`, then `warmOpened`;
- named physical Fire TV profile.

Android Emulator results never qualify this issue.
