/// Cross-platform fullscreen utility
/// Uses conditional imports to provide web fullscreen on web platform
/// and no-op stubs on other platforms
///
/// This pair is shaped differently from the app's other conditional-import
/// sites: the "real" half (`web_fullscreen_web.dart`) uses `dart:html`
/// itself, not `dart:io`/ffi, so `dart.library.io` is not a usable gate here
/// -- flipping to it would try to compile a `dart:html` import on native
/// platforms (where `dart.library.io` is true), breaking Android/iOS/desktop
/// builds outright. The stub is already the default (selected whenever the
/// condition is false), which is the safe shape. What changed is the gate
/// itself: `dart.library.html` is false under dart2wasm, so it silently
/// fell back to the stub there too -- functionally safe (dart:html is not
/// available under wasm either, so the stub is the only valid choice), but
/// it shares the flagged token with the actually-unsafe sites and would trip
/// the repo-wide `dart.library.html` gate. `dart.library.js` selects the
/// same target -- true only for the classic dart2js/dartdevc compile, false
/// for both native and dart2wasm -- so behavior is unchanged.
library;

export 'web_fullscreen_stub.dart'
    if (dart.library.js) 'web_fullscreen_web.dart';
