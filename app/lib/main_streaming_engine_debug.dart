/// QA/debug entrypoint for the receiver streaming engine (SPEC.md
/// AD-1/AD-5, Phase 2 Waves A-C). Boots straight to
/// [StreamingEngineDebugScreen] — bypasses the real app shell entirely so
/// this can't interfere with any real screen/route. Needs the native
/// (Media3/OkHttp) side, so run with `APP_VARIANT=tv`:
///
/// ```bash
/// flutter run -t lib/main_streaming_engine_debug.dart \
///   --dart-define=APP_VARIANT=tv -d <device-id>
/// ```
library;

import 'package:flutter/material.dart';

import 'debug/streaming_engine_debug_screen.dart';

void main() {
  runApp(const _StreamingEngineDebugApp());
}

class _StreamingEngineDebugApp extends StatelessWidget {
  const _StreamingEngineDebugApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Streaming Engine Debug',
      home: StreamingEngineDebugScreen(),
    );
  }
}
