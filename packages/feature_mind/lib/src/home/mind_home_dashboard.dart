import 'dart:async';

import 'package:flutter/material.dart';

import '../quick_capture/application/quick_capture_controller.dart';
import '../quick_capture/presentation/quick_capture_sheet.dart';
import '../runtime/mind_runtime.dart';
import '../runtime/models/capability_models.dart';
import '../runtime/models/context_models.dart';
import '../runtime/models/mesh_models.dart';
import '../runtime/models/vault_models.dart';
import '../widgets/mind_context_chip.dart';
import '../widgets/mind_number_strip.dart';
import '../widgets/mind_palette.dart';
import '../widgets/mind_presence_pip.dart';

/// Surface 01, phone: Mind Home as a runtime dashboard, not a feed.
///
/// Binds to five of [MindRuntime]'s eight sub-ports -- [MindRuntime.vault],
/// [MindRuntime.log], [MindRuntime.contexts], [MindRuntime.capabilities] and
/// [MindRuntime.mesh] -- per the port-first architecture in
/// `docs/superpowers/specs/2026-08-02-airo-mind-device-system-design.md`.
/// Never touches [MindRuntime.projections], [MindRuntime.models] or
/// [MindRuntime.portability]; those belong to other surfaces.
///
/// This is a new widget, not a replacement for `MindHomeScreen` (the legacy
/// screen bound directly to `MindService`). The legacy screen and its route
/// keep working; wiring this dashboard into navigation is a separate pass.
class MindHomeDashboard extends StatefulWidget {
  const MindHomeDashboard({super.key, required this.runtime});

  final MindRuntime runtime;

  @override
  State<MindHomeDashboard> createState() => _MindHomeDashboardState();
}

class _MindHomeDashboardState extends State<MindHomeDashboard> {
  int? _opCount;
  MindPortUnavailable? _opError;

  VaultState? _vaultState;
  MindPortUnavailable? _vaultError;

  List<MindPeer>? _peers;
  MindPortUnavailable? _peersError;

  List<MindContext>? _contexts;
  MindPortUnavailable? _contextsError;

  List<InstalledCapability>? _capabilities;
  MindPortUnavailable? _capabilitiesError;

  StreamSubscription<List<MindPeer>>? _peerSubscription;

  @override
  void initState() {
    super.initState();
    _loadVault();
    _loadLog();
    _loadContexts();
    _loadCapabilities();
    _listenMesh();
  }

  @override
  void dispose() {
    unawaited(_peerSubscription?.cancel());
    super.dispose();
  }

  Future<void> _loadVault() async {
    try {
      final state = await widget.runtime.vault.state();
      if (mounted) setState(() => _vaultState = state);
    } on MindPortUnavailable catch (e) {
      if (mounted) setState(() => _vaultError = e);
    }
  }

  Future<void> _loadLog() async {
    try {
      final count = await widget.runtime.log.count();
      if (mounted) setState(() => _opCount = count);
    } on MindPortUnavailable catch (e) {
      if (mounted) setState(() => _opError = e);
    }
  }

  Future<void> _loadContexts() async {
    try {
      final all = await widget.runtime.contexts.all();
      if (mounted) setState(() => _contexts = all);
    } on MindPortUnavailable catch (e) {
      if (mounted) setState(() => _contextsError = e);
    }
  }

  Future<void> _loadCapabilities() async {
    try {
      final installed = await widget.runtime.capabilities.installed();
      if (mounted) setState(() => _capabilities = installed);
    } on MindPortUnavailable catch (e) {
      if (mounted) setState(() => _capabilitiesError = e);
    }
  }

  /// Streaming methods fail on the stream rather than at call time (per the
  /// architecture spec), so this subscribes and renders an error rather than
  /// throwing before the subscription forms.
  void _listenMesh() {
    _peerSubscription = widget.runtime.mesh.peers().listen(
      (peers) {
        if (mounted) setState(() => _peers = peers);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _peersError = error is MindPortUnavailable
              ? error
              : const MindPortUnavailable('mesh', 'stream failed');
        });
      },
    );
  }

  void _openQuickCapture(BuildContext context) {
    final controller = QuickCaptureController(
      log: widget.runtime.log,
      contexts: widget.runtime.contexts,
    );
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => QuickCaptureSheet(
          controller: controller,
          contextCandidates: _contexts ?? const [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MindPalette.onFilled,
      floatingActionButton: _CaptureKey(
        onPressed: () => _openQuickCapture(context),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MindPresencePip(isLocal: true),
              const SizedBox(height: 16),
              // R04: the ops / peers / vault strip renders above the fold.
              _buildNumberStrip(),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildContextsSummary(),
                    const SizedBox(height: 20),
                    _buildCapabilitiesSummary(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders [MindNumberStrip] only once vault, log and mesh have all
  /// resolved. If any of the three has failed, names each missing sub-port
  /// instead -- the strip has no partial-data mode, and a strip that shows a
  /// guessed zero for a port that is actually down would misreport it as
  /// "working and alone" (the state the design's own zero-cell comment
  /// reserves for a genuine zero). While a fetch is still in flight this
  /// renders nothing: no spinner without a number.
  Widget _buildNumberStrip() {
    final missingPorts = <String>[
      if (_vaultError != null) _vaultError!.port,
      if (_opError != null) _opError!.port,
      if (_peersError != null) _peersError!.port,
    ];

    if (missingPorts.isEmpty &&
        _vaultState != null &&
        _opCount != null &&
        _peers != null) {
      return MindNumberStrip(
        key: const Key('mind.home.numberStrip'),
        opCount: _opCount!,
        peerCount: _peers!.length,
        vaultSealed: _vaultState!.isSealed,
      );
    }

    if (missingPorts.isNotEmpty) {
      return Column(
        key: const Key('mind.home.numberStrip.errors'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final port in missingPorts) _PortUnavailableNotice(port: port),
        ],
      );
    }

    return const SizedBox.shrink(key: Key('mind.home.numberStrip.pending'));
  }

  Widget _buildContextsSummary() {
    if (_contextsError != null) {
      return _PortUnavailableNotice(
        key: const Key('mind.home.contexts.error'),
        port: _contextsError!.port,
      );
    }
    final contexts = _contexts;
    if (contexts == null) {
      return const SizedBox.shrink(key: Key('mind.home.contexts.pending'));
    }
    return Column(
      key: const Key('mind.home.contexts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${contexts.length} CONTEXTS',
          style: const TextStyle(
            color: MindPalette.ink,
            fontSize: 11,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mindContext in contexts)
              MindContextChip(context: mindContext, onTap: () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildCapabilitiesSummary() {
    if (_capabilitiesError != null) {
      return _PortUnavailableNotice(
        key: const Key('mind.home.capabilities.error'),
        port: _capabilitiesError!.port,
      );
    }
    final capabilities = _capabilities;
    if (capabilities == null) {
      return const SizedBox.shrink(
        key: Key('mind.home.capabilities.pending'),
      );
    }
    final active = capabilities.where((c) => c.isActive).length;
    return Text(
      '$active of ${capabilities.length} CAPABILITIES ACTIVE',
      key: const Key('mind.home.capabilities'),
      style: const TextStyle(
        color: MindPalette.ink,
        fontSize: 11,
        letterSpacing: 1.4,
      ),
    );
  }
}

/// Names the missing sub-port rather than the product. Reuses the same
/// phrasing Quick Capture's error state uses for the same reason.
class _PortUnavailableNotice extends StatelessWidget {
  const _PortUnavailableNotice({super.key, required this.port});

  final String port;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('mind.home.portError.$port'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        'The $port is not available.',
        style: const TextStyle(color: MindPalette.alarm, fontSize: 13),
      ),
    );
  }
}

/// "Capture one tap away via the amber key" -- a bottom-sheet trigger for
/// Quick Capture (surface 07, #1454), styled apart from the teal/ink palette
/// so it reads as the one action that is always reachable.
class _CaptureKey extends StatelessWidget {
  const _CaptureKey({required this.onPressed});

  static const Color amber = Color(0xFFFFC107);

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: const Key('mind.home.captureKey'),
      backgroundColor: amber,
      foregroundColor: MindPalette.onFilled,
      onPressed: onPressed,
      child: const Icon(Icons.mic),
    );
  }
}
