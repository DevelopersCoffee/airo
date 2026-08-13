import 'package:flutter/material.dart';

import '../runtime/mind_runtime.dart';
import '../runtime/models/context_models.dart';
import '../runtime/models/portability_models.dart';
import '../widgets/format_bytes.dart';
import '../widgets/mind_palette.dart';
import 'mind_surface_scaffold.dart';

/// Surface 08. Export reads as sealing an envelope: pick contexts, set the
/// phrase, choose a destination on your own network. No progress bar
/// mentions a server because none exists.
class PortabilitySurface extends StatefulWidget {
  const PortabilitySurface({super.key, required this.runtime, this.onBack});

  final MindRuntime runtime;
  final VoidCallback? onBack;

  @override
  State<PortabilitySurface> createState() => _PortabilitySurfaceState();
}

enum _SealState { idle, sealing, sealed }

class _PortabilitySurfaceState extends State<PortabilitySurface> {
  late Future<List<MindContext>> _contexts;
  final Set<String> _selected = {};
  RecoveryPackagePlan? _plan;

  final _passphraseController = TextEditingController();
  bool _obscure = true;
  PackageDestination _destination = PackageDestination.lanPeer;
  _SealState _sealState = _SealState.idle;
  double _sealProgress = 0;

  @override
  void initState() {
    super.initState();
    _contexts = _load();
    _passphraseController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  Future<List<MindContext>> _load() async {
    final all = await widget.runtime.contexts.all();
    // Every context starts selected except one -- the design leaves
    // #AiroArchitecture unchecked as its example of a deliberate exclusion,
    // not because architecture notes are special. The last context in the
    // list plays that role here rather than hardcoding a fixture-specific id.
    _selected
      ..clear()
      ..addAll(all.map((c) => c.id).take(all.length - 1));
    await _recompute();
    return all;
  }

  Future<void> _recompute() async {
    final plan = await widget.runtime.portability.plan(_selected.toList());
    if (mounted) setState(() => _plan = plan);
  }

  Future<void> _toggle(String contextId) async {
    setState(() {
      if (!_selected.remove(contextId)) _selected.add(contextId);
    });
    await _recompute();
  }

  Future<void> _seal() async {
    final plan = _plan;
    if (plan == null || _passphraseController.text.isEmpty) return;

    setState(() {
      _sealState = _SealState.sealing;
      _sealProgress = 0;
    });

    await for (final progress in widget.runtime.portability.seal(
      plan: plan,
      passphrase: _passphraseController.text,
      destination: _destination,
    )) {
      if (!mounted) return;
      setState(
        () => _sealProgress = progress.total == 0
            ? 1
            : progress.written / progress.total,
      );
    }
    if (mounted) setState(() => _sealState = _SealState.sealed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MindContext>>(
      future: _contexts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          final failure = error is MindPortUnavailable
              ? error
              : MindPortUnavailable('MindRuntime', '$error');
          return MindSurfaceScaffold(
            title: 'PORTABILITY',
            status: MindSurfaceStatus.unavailable(failure.port, failure.reason),
            onBack: widget.onBack,
            child: const SizedBox.shrink(),
          );
        }

        final contexts = snapshot.data;
        final plan = _plan;
        if (contexts == null || plan == null) {
          return const MindSurfaceScaffold(
            title: 'PORTABILITY',
            status: MindSurfaceStatus.rebuilding(opsProcessed: 0, opsTotal: 0),
            child: SizedBox.shrink(),
          );
        }

        return MindSurfaceScaffold(
          title: 'PORTABILITY',
          status: const MindSurfaceStatus.live(
            opCount: 0,
            peerCount: 0,
            vaultSealed: true,
          ),
          onBack: widget.onBack,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  children: [
                    _PackageCard(plan: plan),
                    const SizedBox(height: 20),
                    _ContextsSection(
                      contexts: contexts,
                      selected: _selected,
                      onToggle: _toggle,
                    ),
                    const SizedBox(height: 20),
                    _PassphraseSection(
                      controller: _passphraseController,
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                    const SizedBox(height: 20),
                    _DestinationSection(
                      selected: _destination,
                      onSelect: (d) => setState(() => _destination = d),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: _SealButton(
                  state: _sealState,
                  progress: _sealProgress,
                  canSeal: _passphraseController.text.isNotEmpty,
                  onSeal: _seal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.plan});

  final RecoveryPackagePlan plan;

  static const _classColours = {
    'Scans': MindPalette.local,
    'Audio': MindPalette.remote,
  };

  @override
  Widget build(BuildContext context) {
    final total = plan.totalBytes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: MindPalette.grid)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECOVERY PACKAGE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: MindPalette.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                key: const Key('portability.size'),
                formatBytes(total),
                style: const TextStyle(
                  fontFamily: 'AiroRulesExpanded',
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: MindPalette.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: MindPalette.ink.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 8,
            child: Row(
              children: [
                for (final band in plan.breakdown)
                  if (band.bytes > 0)
                    Expanded(
                      flex: band.bytes,
                      child: ColoredBox(
                        color:
                            _classColours[band.label] ??
                            MindPalette.ink.withValues(alpha: 0.5),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final band in plan.breakdown)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stop,
                      size: 10,
                      color:
                          _classColours[band.label] ??
                          MindPalette.ink.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${band.label.toUpperCase()} ${formatBytes(band.bytes)}',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: MindPalette.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContextsSection extends StatelessWidget {
  const _ContextsSection({
    required this.contexts,
    required this.selected,
    required this.onToggle,
  });

  final List<MindContext> contexts;
  final Set<String> selected;
  final void Function(String contextId) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTEXTS INCLUDED',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.2,
            color: MindPalette.ink.withValues(alpha: 0.6),
          ),
        ),
        for (final item in contexts)
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: MindPalette.grid)),
            ),
            child: InkWell(
              onTap: () => onToggle(item.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Checkbox(
                      value: selected.contains(item.id),
                      onChanged: (_) => onToggle(item.id),
                      activeColor: MindPalette.ink,
                      checkColor: MindPalette.onFilled,
                      side: BorderSide(
                        color: MindPalette.ink.withValues(alpha: 0.4),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: MindPalette.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${item.itemCount} items',
                      style: TextStyle(
                        fontSize: 11,
                        color: MindPalette.ink.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PassphraseSection extends StatelessWidget {
  const _PassphraseSection({
    required this.controller,
    required this.obscure,
    required this.onToggleObscure,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSPHRASE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.2,
            color: MindPalette.ink.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(border: Border.all(color: MindPalette.ink)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 2,
                    color: MindPalette.ink,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: MindPalette.ink.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'If you lose this phrase, the package cannot be opened. Not by '
          'you, not by us — there is no reset.',
          style: TextStyle(
            fontSize: 11,
            height: 1.45,
            color: MindPalette.ink.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _DestinationSection extends StatelessWidget {
  const _DestinationSection({required this.selected, required this.onSelect});

  final PackageDestination selected;
  final void Function(PackageDestination destination) onSelect;

  static const _options = [
    (
      destination: PackageDestination.lanPeer,
      icon: Icons.lan_outlined,
      label: 'iPad · LAN',
    ),
    (
      destination: PackageDestination.thisDevice,
      icon: Icons.folder_outlined,
      label: 'THIS DEVICE',
    ),
    (
      destination: PackageDestination.usbDrive,
      icon: Icons.usb,
      label: 'USB DRIVE',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEND TO',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.2,
            color: MindPalette.ink.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final option in _options) ...[
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(option.destination),
                  child: Container(
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: option.destination == selected
                            ? MindPalette.local
                            : MindPalette.grid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          option.icon,
                          size: 21,
                          color: option.destination == selected
                              ? MindPalette.local
                              : MindPalette.ink,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            color: option.destination == selected
                                ? MindPalette.local
                                : MindPalette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (option != _options.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _SealButton extends StatelessWidget {
  const _SealButton({
    required this.state,
    required this.progress,
    required this.canSeal,
    required this.onSeal,
  });

  final _SealState state;
  final double progress;
  final bool canSeal;
  final VoidCallback onSeal;

  @override
  Widget build(BuildContext context) {
    if (state == _SealState.sealing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: MindPalette.grid,
              valueColor: const AlwaysStoppedAnimation(MindPalette.local),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'SEALING…',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: MindPalette.ink,
            ),
          ),
        ],
      );
    }

    if (state == _SealState.sealed) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: MindPalette.local)),
        child: const Text(
          'Sealed · ready to send',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.5,
            color: MindPalette.local,
          ),
        ),
      );
    }

    return InkWell(
      onTap: canSeal ? onSeal : null,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        color: canSeal
            ? MindPalette.ink
            : MindPalette.ink.withValues(alpha: 0.3),
        child: const Text(
          'SEAL PACKAGE',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            color: MindPalette.onFilled,
          ),
        ),
      ),
    );
  }
}
