import 'package:flutter/material.dart';

import '../runtime/mind_runtime.dart';
import '../runtime/models/capability_models.dart';
import '../runtime/models/context_models.dart';
import '../runtime/models/log_models.dart';
import '../widgets/mind_context_chip.dart';
import '../widgets/mind_op_row.dart';
import '../widgets/mind_palette.dart';
import 'mind_surface_scaffold.dart';

/// Surface 01. Home is a runtime dashboard, not a feed.
///
/// Ops, peers and vault state sit above the fold because they are the claim
/// the product makes; a list of recent items would bury them. Capture is one
/// tap away, and the context guess happens after capture rather than before —
/// see [QuickCapture].
class MindHomeSurface extends StatefulWidget {
  const MindHomeSurface({
    super.key,
    required this.runtime,
    this.onOpenContext,
    this.onOpenCapability,
    this.onCapture,
    this.onOpenOp,
  });

  final MindRuntime runtime;
  final void Function(MindContext context)? onOpenContext;
  final void Function(InstalledCapability capability)? onOpenCapability;
  final void Function(MindCaptureKind kind)? onCapture;
  final void Function(MindOp op)? onOpenOp;

  @override
  State<MindHomeSurface> createState() => _MindHomeSurfaceState();
}

/// The three ways to get something into the log from Home.
enum MindCaptureKind { voice, note, scan }

class _MindHomeSurfaceState extends State<MindHomeSurface> {
  late Future<_HomeData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_HomeData> _load() async {
    // Each read is a separate port call rather than one aggregate, so a
    // partial runtime fails on the port it actually lacks.
    final opCount = await widget.runtime.log.count();
    final peers = await widget.runtime.mesh.peers().first;
    final vault = await widget.runtime.vault.state();
    final contexts = await widget.runtime.contexts.all();
    final capabilities = await widget.runtime.capabilities.installed();
    final recent = await widget.runtime.log.range(offset: 0, limit: 2);

    return _HomeData(
      opCount: opCount,
      peerCount: peers.length,
      vaultSealed: vault.isSealed,
      contexts: contexts,
      capabilities: capabilities,
      recent: recent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          final failure = error is MindPortUnavailable
              ? error
              : MindPortUnavailable('MindRuntime', '$error');
          return MindSurfaceScaffold(
            title: 'MIND',
            status: MindSurfaceStatus.unavailable(failure.port, failure.reason),
            child: const SizedBox.shrink(),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          // Not "loading" in the abstract — the log is being counted, and the
          // scaffold says so with a number as soon as it has one.
          return const MindSurfaceScaffold(
            title: 'MIND',
            status: MindSurfaceStatus.rebuilding(opsProcessed: 0, opsTotal: 0),
            child: SizedBox.shrink(),
          );
        }

        return MindSurfaceScaffold(
          title: 'MIND',
          status: MindSurfaceStatus.live(
            opCount: data.opCount,
            peerCount: data.peerCount,
            vaultSealed: data.vaultSealed,
          ),
          trailing: const _HeaderActions(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              _CaptureRow(onCapture: widget.onCapture),
              const SizedBox(height: 20),
              _ContextSection(
                contexts: data.contexts,
                onOpen: widget.onOpenContext,
              ),
              const SizedBox(height: 20),
              _CapabilitySection(
                capabilities: data.capabilities,
                onOpen: widget.onOpenCapability,
              ),
              const SizedBox(height: 20),
              _RecentSection(ops: data.recent, onOpen: widget.onOpenOp),
            ],
          ),
        );
      },
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.opCount,
    required this.peerCount,
    required this.vaultSealed,
    required this.contexts,
    required this.capabilities,
    required this.recent,
  });

  final int opCount;
  final int peerCount;
  final bool vaultSealed;
  final List<MindContext> contexts;
  final List<InstalledCapability> capabilities;
  final List<MindOp> recent;
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search, color: MindPalette.ink, size: 22),
        SizedBox(width: 16),
        Icon(Icons.sync, color: MindPalette.local, size: 22),
        SizedBox(width: 6),
      ],
    );
  }
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow({required this.onCapture});

  final void Function(MindCaptureKind kind)? onCapture;

  static const _kinds = {
    MindCaptureKind.voice: (Icons.mic_none, 'VOICE'),
    MindCaptureKind.note: (Icons.edit_note, 'NOTE'),
    MindCaptureKind.scan: (Icons.document_scanner_outlined, 'SCAN'),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in _kinds.entries) ...[
          Expanded(
            child: InkWell(
              onTap: () => onCapture?.call(entry.key),
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  border: Border.all(color: MindPalette.grid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(entry.value.$1, color: MindPalette.remote, size: 22),
                    const SizedBox(height: 7),
                    Text(
                      entry.value.$2,
                      style: const TextStyle(
                        color: MindPalette.ink,
                        fontSize: 9,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (entry.key != MindCaptureKind.scan) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: MindPalette.ink,
              fontSize: 10,
              letterSpacing: 2.2,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                color: MindPalette.ink.withValues(alpha: 0.45),
                fontSize: 10,
                letterSpacing: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextSection extends StatelessWidget {
  const _ContextSection({required this.contexts, required this.onOpen});

  final List<MindContext> contexts;
  final void Function(MindContext context)? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          label: 'CONTEXTS',
          trailing: '${contexts.length} ACTIVE',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, item) in contexts.indexed)
              MindContextChip(
                context: item,
                // The first is selected in the design; selection here is
                // presentational until the hypergraph browser lands.
                isSelected: index == 0,
                onTap: () => onOpen?.call(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _CapabilitySection extends StatelessWidget {
  const _CapabilitySection({required this.capabilities, required this.onOpen});

  final List<InstalledCapability> capabilities;
  final void Function(InstalledCapability capability)? onOpen;

  static const _icons = {
    'hospital_recovery': Icons.healing_outlined,
    'property_maintenance': Icons.home_repair_service_outlined,
    'tax_2026': Icons.receipt_long_outlined,
    'audio_scribe': Icons.graphic_eq,
    'prompt_lab': Icons.science_outlined,
  };

  @override
  Widget build(BuildContext context) {
    // The design shows four cards; a fifth capability would overflow the grid,
    // so Home shows the first four and Capability Packs shows them all.
    final shown = capabilities.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'CAPABILITIES'),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final capability in shown)
              InkWell(
                onTap: () => onOpen?.call(capability),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    border: Border.all(color: MindPalette.grid),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _icons[capability.id] ?? Icons.extension_outlined,
                        color:
                            capability.safetyClass ==
                                CapabilitySafetyClass.health
                            ? MindPalette.local
                            : MindPalette.ink,
                        size: 19,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        capability.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MindPalette.ink,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      // The design shows a per-capability status line ("2 MEDS
                      // DUE TODAY"). No port supplies one, so this reports the
                      // item count rather than inventing a number. See the
                      // capability-status feature request.
                      Text(
                        '${capability.itemCount} ITEMS',
                        style: TextStyle(
                          color: MindPalette.ink.withValues(alpha: 0.5),
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.ops, required this.onOpen});

  final List<MindOp> ops;
  final void Function(MindOp op)? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'RECENT IN THE LOG'),
        for (final op in ops)
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: MindPalette.grid)),
            ),
            child: MindOpRow(op: op, onTap: () => onOpen?.call(op)),
          ),
      ],
    );
  }
}
