import 'package:flutter/material.dart';
import 'package:platform_streaming_engine/platform_streaming_engine.dart';

/// QA/debug harness for the receiver streaming engine
/// (docs/specs/tv-zero-copy-cast.md AD-1/AD-5,
/// Phase 2 Waves A-C). Not the real "Play on TV" UX (that's Phase 4's
/// cast protocol work, which decides which channel/source list this
/// screen would eventually receive) — this exists purely so the native
/// engine has something reachable to tap on a device before that UI
/// exists. Reached via [main_streaming_engine_debug.dart], never wired
/// into the real app shell.
class StreamingEngineDebugScreen extends StatefulWidget {
  const StreamingEngineDebugScreen({super.key});

  @override
  State<StreamingEngineDebugScreen> createState() => _StreamingEngineDebugScreenState();
}

class _StreamingEngineDebugScreenState extends State<StreamingEngineDebugScreen> {
  final _shadowFetchUrlController = TextEditingController(
    text: 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8',
  );
  final _switchSourceUrlController = TextEditingController(
    text: 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8',
  );

  String _pingStatus = 'not called yet';
  String _preWarmStatus = 'not called yet';
  String _shadowFetchStatus = 'not called yet';
  String _switchSourceStatus = 'not called yet';
  AiroPlaybackEnginePhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    AiroStreamingEngineState.phaseStream.listen((phase) {
      if (!mounted) return;
      setState(() => _lastPhase = phase);
    });
  }

  @override
  void dispose() {
    _shadowFetchUrlController.dispose();
    _switchSourceUrlController.dispose();
    super.dispose();
  }

  Future<void> _callPing() async {
    setState(() => _pingStatus = 'calling...');
    final result = await AiroStreamingEngineChannel.ping();
    setState(() => _pingStatus = result ? 'ok: true' : 'ok: false');
  }

  Future<void> _callPreWarm() async {
    setState(() => _preWarmStatus = 'calling...');
    await AiroStreamingEngineChannel.preWarm(['devstreaming-cdn.apple.com']);
    setState(() => _preWarmStatus = 'done (fire-and-forget, check logcat for native errors)');
  }

  Future<void> _callShadowFetch() async {
    setState(() => _shadowFetchStatus = 'calling...');
    final outcome = await AiroStreamingEngineChannel.shadowFetch(_shadowFetchUrlController.text);
    setState(() {
      _shadowFetchStatus = switch (outcome) {
        AiroShadowFetchMeasured(:final throughputKbps) => 'measured: ${throughputKbps.toStringAsFixed(1)} kbps',
        AiroShadowFetchFailed(:final reason) => 'failed: $reason',
        AiroShadowFetchBusy() => 'busy (limiter rejected)',
      };
    });
  }

  Future<void> _callSwitchSource() async {
    setState(() => _switchSourceStatus = 'calling...');
    final result = await AiroStreamingEngineChannel.switchSource(_switchSourceUrlController.text);
    setState(() {
      _switchSourceStatus = switch (result) {
        AiroSwitchSourceSpliced() => 'spliced',
        AiroSwitchSourceFellBackToMuteCut() => 'fell back to mute-cut',
        AiroSwitchSourceFailed() => 'failed (no active player?)',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Streaming Engine Debug')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Video surface (Wave A) — should show the bipbop test stream once the native side is running.',
            ),
            const SizedBox(height: 8),
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: AiroStreamingSurfaceView(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Last phase (STATE stream, Task 5): ${_lastPhase?.stableId ?? "none yet"}'),
            const Divider(height: 32),

            Text('ping (Task 1): $_pingStatus'),
            ElevatedButton(onPressed: _callPing, child: const Text('Call ping()')),
            const Divider(height: 32),

            Text('preWarm (Wave B Task 4): $_preWarmStatus'),
            ElevatedButton(onPressed: _callPreWarm, child: const Text('Call preWarm()')),
            const Divider(height: 32),

            Text('shadowFetch (Wave C Task 1): $_shadowFetchStatus'),
            TextField(
              controller: _shadowFetchUrlController,
              decoration: const InputDecoration(labelText: 'Shadow-fetch URL'),
            ),
            ElevatedButton(onPressed: _callShadowFetch, child: const Text('Call shadowFetch()')),
            const Divider(height: 32),

            Text('switchSource (splice-on-keyframe): $_switchSourceStatus'),
            TextField(
              controller: _switchSourceUrlController,
              decoration: const InputDecoration(labelText: 'Switch-source URL'),
            ),
            ElevatedButton(onPressed: _callSwitchSource, child: const Text('Call switchSource()')),
          ],
        ),
      ),
    );
  }
}
