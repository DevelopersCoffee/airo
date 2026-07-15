// Public API surface — these functions are exposed to Flutter via FFI.
// Rules:
//   - No panics. Use anyhow::Result or plain return values.
//   - Keep payloads small (< 64 KB per call); batch large data.
//   - Every function must have a pure-Dart fallback path on the Dart side.

pub mod epg;
pub mod m3u;
pub mod text;
