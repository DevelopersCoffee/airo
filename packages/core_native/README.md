# core_native

Flutter bindings for the reusable `airo_core` Rust crate.

## Native Bridge

Generate bindings from the repository root:

```bash
flutter_rust_bridge_codegen generate
```

The generator reads `flutter_rust_bridge.yaml` and writes:

- `packages/core_native/lib/src/frb_generated.dart`
- `packages/core_native/lib/src/frb_generated.io.dart`
- `packages/core_native/lib/src/frb_generated.web.dart`
- `packages/core_native/lib/src/api/*.dart`
- `rust/airo_core/src/frb_generated.rs`

App entrypoints can call `initializeCoreNativeBridge()` after
`WidgetsFlutterBinding.ensureInitialized()`. The initializer returns `false`
when the native library is unavailable so callers can keep deterministic Dart
fallbacks.

For local native verification, build the release library at the generated
loader path:

```bash
cd rust
CARGO_TARGET_DIR="$PWD/airo_core/target" cargo build -p airo_core --release
```

Then verify an XMLTV file reaches the generated native bridge:

```bash
cd packages/core_native
CORE_NATIVE_XMLTV_FIXTURE=/path/to/guide.xml \
flutter test test/xmltv_native_bridge_verification_test.dart
```

## Public API

Use `package:core_native/core_native.dart`; do not import generated FRB files
from feature packages.

Synchronous APIs remain deterministic Dart fallback paths:

- `normalizeChannelName`
- `parseM3uEntries`
- `parseM3uChannelsWithStats`
- `parseXmltvProgrammes`
- `parseXmltvProgrammesFile`

Native-preferred async APIs call Rust through the generated bridge when it is
initialized and fall back to the same Dart behavior when unavailable:

- `normalizeChannelNameNative`
- `parseM3uEntriesNative`
- `parseM3uChannelsWithStatsNative`
- `parseM3uFileChannelsWithStatsNative`
- `parseXmltvProgrammesNative`
- `parseXmltvProgrammesFileNative`
