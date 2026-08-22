import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../assistant/consent/mind_runtime_provider.dart';
import '../notes/domain/notes_operation_log.dart';
import '../notes/notes_capability.dart';
import '../notes/presentation/notes_screen.dart';
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
            subtitle: const Text('Rust notes log + restart persistence'),
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

/// Notes with Rust preferred path when Mind has booted.
class MindRuntimeNotesScreen extends StatefulWidget {
  const MindRuntimeNotesScreen({super.key});

  @override
  State<MindRuntimeNotesScreen> createState() => _MindRuntimeNotesScreenState();
}

class _MindRuntimeNotesScreenState extends State<MindRuntimeNotesScreen> {
  NotesCapability? _capability;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final base = await getApplicationSupportDirectory();
      final path = p.join(base.path, 'airo_mind', 'notes.log');
      final log = await NotesOperationLog.open(path);
      if (!mounted) return;
      setState(() => _capability = NotesCapability.rustPreferred(log));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notes')),
        body: Center(child: Text('Could not open notes log: $_error')),
      );
    }
    if (_capability == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: NotesScreen(capability: _capability!),
    );
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
