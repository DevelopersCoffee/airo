import 'package:core_ui/core_ui.dart' show AiroFold, FoldPosture;
import 'package:flutter/material.dart';

import '../runtime/mind_runtime.dart' show MindPortUnavailable;
import '../runtime/models/context_models.dart';
import '../runtime/models/log_models.dart';
import '../runtime/models/projection_models.dart';
import '../runtime/ports/context_port.dart';
import '../runtime/ports/operation_log_port.dart';
import '../runtime/ports/projection_port.dart';
import '../widgets/mind_context_chip.dart';
import '../widgets/mind_op_row.dart';
import '../widgets/mind_palette.dart';
import '../widgets/mind_presence_pip.dart';
import '../widgets/mind_projection_switcher.dart';

/// Surface 09. Tablet split-pane over [ProjectionPort], [ContextPort] and
/// [OperationLogPort].
///
/// The wider-canvas composition over the same three ports Memory·Projections
/// (surface 04, phone) binds — not a separate feature. Below the tablet
/// breakpoint this collapses to the same single-pane shape a phone gets:
/// a context list, and — once a context is picked — its detail. At and above
/// the breakpoint both render side by side, because a tablet has room to show
/// the choice and its consequence at once.
///
/// Binds three ports, not the whole [MindRuntime] — "no consumer takes a
/// dependency wider than it uses" (`docs/superpowers/specs/`
/// `2026-08-02-airo-mind-device-system-design.md`). That is also why this
/// surface does not render [MindNumberStrip]: that widget's peer and vault
/// cells need [MeshPort] and [VaultPort], neither of which this surface
/// binds, and printing a fabricated zero for a port it cannot ask would be
/// exactly the false claim R04's own docstring warns against. What this
/// surface does know — the log's op count — stays visible in the header
/// instead, satisfying R04's intent with the numbers it actually has.
class ContextWorkspaceSurface extends StatefulWidget {
  const ContextWorkspaceSurface({
    super.key,
    required this.contexts,
    required this.log,
    required this.projections,
    required this.localDeviceName,
  });

  final ContextPort contexts;
  final OperationLogPort log;
  final ProjectionPort projections;

  /// This device's name, as it appears in [MindOp.deviceName].
  ///
  /// Compared against each op's provenance to render R01's pip honestly.
  /// This surface binds no [VaultPort], so it has no other way to know which
  /// device is "this one" — the caller, which does hold a vault binding
  /// elsewhere in the shell, supplies it.
  final String localDeviceName;

  /// How many ops to page in for the detail pane's client-side filter.
  ///
  /// [OperationLogPort] has no "ops for context" query — the same gap surface
  /// 04 found and left for a port change, not something to paper over here.
  static const int opPageSize = 50;

  /// The width at and above which the split-pane composition applies.
  ///
  /// Matches the tablet breakpoint documented in
  /// `docs/ui/RESPONSIVE_STANDARDS.md` (600–1024px is "Tablet") — the same
  /// number `AiroFormFactor.tablet`'s own boundary in core_ui resolves from,
  /// not a bespoke pick for this surface.
  static const double tabletBreakpoint = 600;

  @override
  State<ContextWorkspaceSurface> createState() =>
      _ContextWorkspaceSurfaceState();
}

class _ContextWorkspaceSurfaceState extends State<ContextWorkspaceSurface> {
  late Future<List<MindContext>> _contextsFuture;
  late Future<List<MindOp>> _opsFuture;
  late Future<List<ProjectionState>> _projectionsFuture;

  String? _selectedContextId;
  ProjectionKind _selectedProjection = ProjectionKind.graph;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _contextsFuture = widget.contexts.all();
    _opsFuture = widget.log.range(
      offset: 0,
      limit: ContextWorkspaceSurface.opPageSize,
    );
    _projectionsFuture = widget.projections.states();

    // The detail pane's FutureBuilders — including the projection status
    // line — mount only once a context is selected, which can be well after
    // this frame. A port that fails before then would otherwise complete
    // with no listener attached and get reported as an unhandled error.
    // `.ignore()` marks it fire-and-forget for that purpose only; each
    // FutureBuilder below still attaches its own independent listener to the
    // same Future and sees the real result, including the error.
    _contextsFuture.ignore();
    _opsFuture.ignore();
    _projectionsFuture.ignore();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= ContextWorkspaceSurface.tabletBreakpoint;
        final fold = AiroFold.of(context);
        // Never let the split-pane straddle a hinge in book posture — the
        // foldable crease rule, `AiroFold.straddles`. Falling back to the
        // single-pane layout keeps primary content off the crease instead of
        // stretching the list/detail split across it.
        final straddlesCrease =
            fold.posture == FoldPosture.halfOpened &&
            AiroFold.straddles(Offset.zero & constraints.biggest, fold);
        final useSplitPane = wide && !straddlesCrease;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(opsFuture: _opsFuture),
            Expanded(
              key: Key(
                useSplitPane
                    ? 'mind.contextWorkspace.splitPane'
                    : 'mind.contextWorkspace.singlePane',
              ),
              child: useSplitPane ? _buildSplitPane() : _buildSinglePane(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSplitPane() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: _buildContextList()),
        const VerticalDivider(width: 1),
        Expanded(flex: 3, child: _buildDetail()),
      ],
    );
  }

  Widget _buildSinglePane() {
    if (_selectedContextId == null) return _buildContextList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => setState(() => _selectedContextId = null),
          child: const Text('BACK TO CONTEXTS'),
        ),
        Expanded(child: _buildDetail()),
      ],
    );
  }

  Widget _buildContextList() {
    return FutureBuilder<List<MindContext>>(
      future: _contextsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = snapshot.error;
        if (error != null) return _PortErrorView(error: error);

        final contexts = snapshot.data!;
        if (contexts.isEmpty) {
          return const Center(child: Text('No contexts yet.'));
        }
        return ListView.builder(
          key: const Key('mind.contextWorkspace.contextList'),
          itemCount: contexts.length,
          itemBuilder: (context, index) {
            final mindContext = contexts[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: MindContextChip(
                context: mindContext,
                isSelected: mindContext.id == _selectedContextId,
                onTap: () =>
                    setState(() => _selectedContextId = mindContext.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetail() {
    final selectedId = _selectedContextId;
    if (selectedId == null) {
      return const Center(child: Text('Select a context.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MindProjectionSwitcher(
          selected: _selectedProjection,
          onChanged: (kind) => setState(() => _selectedProjection = kind),
        ),
        _ProjectionStatusLine(
          projectionsFuture: _projectionsFuture,
          kind: _selectedProjection,
        ),
        Expanded(
          child: _OpsForContext(
            opsFuture: _opsFuture,
            contextId: selectedId,
            localDeviceName: widget.localDeviceName,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.opsFuture});

  final Future<List<MindOp>> opsFuture;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          const MindPresencePip(isLocal: true),
          const Spacer(),
          FutureBuilder<List<MindOp>>(
            future: opsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done ||
                  snapshot.hasError) {
                return const SizedBox.shrink();
              }
              return Text(
                key: const Key('mind.contextWorkspace.opsVisible'),
                '${snapshot.data!.length} ops shown',
                style: const TextStyle(fontSize: 11, letterSpacing: 1),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProjectionStatusLine extends StatelessWidget {
  const _ProjectionStatusLine({
    required this.projectionsFuture,
    required this.kind,
  });

  final Future<List<ProjectionState>> projectionsFuture;
  final ProjectionKind kind;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProjectionState>>(
      future: projectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 20,
            child: Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final error = snapshot.error;
        if (error != null) return _PortErrorView(error: error, compact: true);

        final state = snapshot.data!.firstWhere((s) => s.kind == kind);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            key: const Key('mind.contextWorkspace.projectionStatus'),
            _label(state),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              color: MindPalette.ink.withValues(alpha: 0.7),
            ),
          ),
        );
      },
    );
  }

  String _label(ProjectionState state) {
    switch (state.status) {
      case ProjectionStatus.rebuilding:
        // Never a bare spinner: ops processed of ops total, always.
        return 'REBUILDING · ${state.opsProcessed}/${state.opsTotal}';
      case ProjectionStatus.queued:
        return 'QUEUED · ${state.opsProcessed}/${state.opsTotal}';
      case ProjectionStatus.stale:
        return 'STALE';
      case ProjectionStatus.fresh:
        final seconds = state.lastRebuildMs / 1000;
        return 'REBUILT ${seconds.toStringAsFixed(1)}S AGO';
    }
  }
}

class _OpsForContext extends StatelessWidget {
  const _OpsForContext({
    required this.opsFuture,
    required this.contextId,
    required this.localDeviceName,
  });

  final Future<List<MindOp>> opsFuture;
  final String contextId;
  final String localDeviceName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MindOp>>(
      future: opsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = snapshot.error;
        if (error != null) return _PortErrorView(error: error);

        final ops = snapshot.data!
            .where((op) => op.contextId == contextId)
            .toList(growable: false);

        if (ops.isEmpty) {
          return const Center(child: Text('No ops for this context yet.'));
        }

        final mostRecent = ops.first;
        final isLocal = mostRecent.deviceName == localDeviceName;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: MindPresencePip(
                key: const Key('mind.contextWorkspace.provenancePip'),
                isLocal: isLocal,
                // Honest attribution when the last write came from a peer
                // this surface has no live status for — it binds no
                // MeshPort, so "offline" is not a claim it can make; naming
                // the device instead of asserting locality is the truthful
                // middle ground.
                remoteLabel: isLocal ? null : mostRecent.deviceName,
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const Key('mind.contextWorkspace.opList'),
                itemCount: ops.length,
                itemBuilder: (context, index) => MindOpRow(op: ops[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PortErrorView extends StatelessWidget {
  const _PortErrorView({required this.error, this.compact = false});

  final Object error;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final message = error is MindPortUnavailable
        ? (error as MindPortUnavailable).toString()
        : 'This pane is unavailable right now.';
    final child = Text(
      key: const Key('mind.contextWorkspace.portError'),
      message,
      style: TextStyle(fontSize: compact ? 11 : 13, color: MindPalette.alarm),
    );
    return compact ? child : Center(child: child);
  }
}
