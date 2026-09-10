# m3u_parser

M3U/M3U8 playlist parser for Flutter. Rust-accelerated on Android, iOS, and
macOS; falls back to an identical pure-Dart implementation on web or
whenever the native bridge is unavailable.

## Usage

```dart
import 'package:m3u_parser/m3u_parser.dart';

// Synchronous, pure-Dart — works everywhere, including web.
final playlist = parseM3u(m3uContent);

// Rust-preferred with automatic fallback. Prefer this when you don't need
// a guaranteed-synchronous call.
final playlist = await parseM3uAsync(m3uContent);

// Aggregate-only stats (no playlist content), for progress/telemetry.
final result = await parseM3uWithStatsAsync(m3uContent);
print('${result.stats.parsedCount} parsed, ${result.stats.skippedCount} skipped');

// Validated, normalized, deduplicated channel records.
final channels = await parseM3uChannelsWithStatsAsync(m3uContent);
```

## Threading

**This package spawns no isolates internally.** Every function here is a
plain, synchronous-under-the-hood call (the `*Async` variants are async
only because they may cross the FFI boundary, not because they do their
own off-main dispatch). If you're parsing a playlist larger than roughly
50 KB, wrap the call in your own isolate/worker boundary — don't call these
functions directly from a UI-thread hot path. This is a deliberate
constraint, not an oversight: a package with an opinion about isolates
inside it would fight whatever concurrency model its host app already has.

## Scope

This package parses M3U text into structured channel entries. It does not
fetch playlists over HTTP, cache responses, manage multiple playlist
sources, or deduplicate/rank channels across sources — those are
application concerns. If you need HTTP fetching with ETag caching and
BYOC-style source management, that layer is straightforward to build on
top of this package's `parseM3u`/`parseM3uAsync`.

## Platform support

| Platform | Parser used |
|---|---|
| Android, iOS, macOS | Rust (native), Dart fallback if the bridge fails to load |
| Web | Pure Dart (no native bridge exists on web) |
| Linux, Windows | Rust (native), Dart fallback if the bridge fails to load |

## License

MIT
