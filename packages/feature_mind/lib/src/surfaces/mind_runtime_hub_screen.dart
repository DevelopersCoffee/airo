import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../assistant/consent/mind_runtime_provider.dart';
import '../notebook/presentation/notebook_host_screen.dart';
import '../runtime_console/runtime_console_controller.dart';
import '../runtime_console/runtime_console_table.dart';
import 'devices_surface.dart';

/// macOS / desktop entry for Wave 2 runtime surfaces used in on-device verification.
///
/// Scribe home stays minimal; Devices (#1592), Notes, and Runtime Console
/// (#1216 `replayFrom`) live here until the Everything Browser wires them in.
class MindRuntimeHubScreen extends ConsumerWidget {
  const MindRuntimeHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mind runtime')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Devices'),
            subtitle: const Text('This device + vault fingerprints (#1592)'),
            onTap: () => context.push('/runtime/devices'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Notes'),
            subtitle: const Text(
              'Record, import, summarise, tag, search, and share',
            ),
            onTap: () => context.push('/runtime/notes'),
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Runtime console'),
            subtitle: const Text('Right-click op → replayFrom (#1216)'),
            onTap: () => context.push('/runtime/console'),
          ),
        ],
      ),
    );
  }
}

/// Devices surface with a live wall clock for [DevicesSurface].
class MindRuntimeDevicesScreen extends ConsumerWidget {
  const MindRuntimeDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(mindRuntimeProvider);
    return DevicesSurface(
      runtime: runtime,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      onBack: () => context.pop(),
    );
  }
}

/// Notes host used by the runtime hub and the scribe `/notes` route.
class MindRuntimeNotesScreen extends StatelessWidget {
  const MindRuntimeNotesScreen({super.key, this.onRecordLive});

  final Future<void> Function()? onRecordLive;

  @override
  Widget build(BuildContext context) {
    return NotebookHostScreen(onRecordLive: onRecordLive);
  }
}

/// Runtime console backed by the shared [mindRuntimeProvider] log.
class MindRuntimeConsoleScreen extends ConsumerStatefulWidget {
  const MindRuntimeConsoleScreen({super.key});

  @override
  ConsumerState<MindRuntimeConsoleScreen> createState() =>
      _MindRuntimeConsoleScreenState();
}

class _MindRuntimeConsoleScreenState
    extends ConsumerState<MindRuntimeConsoleScreen> {
  RuntimeConsoleController? _controller;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final log = ref.read(mindRuntimeProvider).log;
    _controller = RuntimeConsoleController(log: log);
    unawaited(_controller!.loadInitial());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Runtime console'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: RuntimeConsoleTable(controller: controller),
    );
  }
}
