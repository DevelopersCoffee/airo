// Public API surface — these functions are exposed to Flutter via FFI.
// Rules:
//   - No panics. Use anyhow::Result or plain return values.
//   - Prefer small payloads. Large import APIs must be worker-backed and
//     document batching or streaming follow-up when they cross FFI.
//   - Every function must have a pure-Dart fallback path on the Dart side.

pub mod m3u;
pub mod text;
