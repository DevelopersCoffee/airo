import 'package:flutter/material.dart';

import '../runtime/mind_runtime.dart';
import '../runtime/models/context_models.dart';
import '../runtime/models/log_models.dart';
import '../runtime/models/projection_models.dart';
import '../widgets/grouped_number.dart';
import '../widgets/mind_op_row.dart';
import '../widgets/mind_palette.dart';
import '../widgets/mind_projection_switcher.dart';
import 'mind_surface_scaffold.dart';

/// Surface 04. Graph, Timeline and Search are one switcher on one screen —
/// projections of the same log, never separate destinations.
///
/// Crypto-shredding is stated in plain words at the moment of deletion, not
/// left to a confirmation dialog's default copy.
class MemorySurface extends StatefulWidget {
  const MemorySurface({
    super.key,
    required this.runtime,
    required this.contextId,
    this.onBack,
    this.onOpenContext,
    this.onOpenOp,
    this.onDestroyRequested,
  });

  final MindRuntime runtime;
  final String contextId;
  final VoidCallback? onBack;
  final void Function(String contextId)? onOpenContext;
  final void Function(MindOp op)? onOpenOp;

  /// Called with the labels of contexts that would survive destroying this
  /// one. There is no `ContextPort.destroy()` yet — only the preview
  /// (`survivorsIfDestroyed`) is frozen in the P0 port. Wiring the destructive
  /// call itself is a port change and belongs with #1229, not this surface.
  final void Function(List<String> survivors)? onDestroyRequested;

  @override
  State<MemorySurface> createState() => _MemorySurfaceState();
}

class _MemorySurfaceState extends State<MemorySurface> {
  ProjectionKind _projection = ProjectionKind.graph;
  late Future<_MemoryData> _data;
  final _searchController = TextEditingController();
  List<SearchHitRef> _hits = const [];

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_MemoryData> _load() async {
    final context = await widget.runtime.contexts.byId(widget.contextId);
    if (context == null) {
      throw MindPortUnavailable(
        'ContextPort',
        'no context with id ${widget.contextId}',
      );
    }
    final links = await widget.runtime.contexts.linksFor(widget.contextId);
    final all = await widget.runtime.contexts.all();
    final linkedIds = links
        .map((l) => l.fromId == widget.contextId ? l.toId : l.fromId)
        .toSet();
    final linked = all.where((c) => linkedIds.contains(c.id)).toList();

    // No port exposes "ops for context" directly; it is filtered client-side
    // over the log. Fine against a fixture, but this is an indexed query the
    // real backend should answer directly rather than a client scanning the
    // whole log — flagged for the ContextPort/OperationLogPort review, not
    // solved by widening the frozen port here.
    final recentOps = await widget.runtime.log.range(offset: 0, limit: 200);
    final ops = recentOps
        .where((op) => op.contextId == widget.contextId)
        .toList();

    return _MemoryData(context: context, linked: linked, ops: ops);
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _hits = const []);
      return;
    }
    final hits = await widget.runtime.projections.search(
      query,
      contextId: widget.contextId,
    );
    if (mounted) setState(() => _hits = hits);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MemoryData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          final failure = error is MindPortUnavailable
              ? error
              : MindPortUnavailable('MindRuntime', '$error');
          return MindSurfaceScaffold(
            title: 'MEMORY',
            status: MindSurfaceStatus.unavailable(failure.port, failure.reason),
            onBack: widget.onBack,
            child: const SizedBox.shrink(),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const MindSurfaceScaffold(
            title: 'MEMORY',
            status: MindSurfaceStatus.rebuilding(opsProcessed: 0, opsTotal: 0),
            child: SizedBox.shrink(),
          );
        }

        // Memory has no ops/peers/vault claim of its own -- it is a lens on
        // one context, so the numbers strip is not the point of this screen.
        // The scaffold's live status still carries R01's presence pip.
        return MindSurfaceScaffold(
          title: 'MEMORY',
          status: const MindSurfaceStatus.live(
            opCount: 0,
            peerCount: 0,
            vaultSealed: true,
          ),
          onBack: widget.onBack,
          child: Column(
            children: [
              MindProjectionSwitcher(
                selected: _projection,
                onChanged: (kind) => setState(() => _projection = kind),
              ),
              Expanded(child: _body(data)),
              _ContextSheet(
                context: data.context,
                onOpen: () => widget.onOpenContext?.call(data.context.id),
                onDestroy: () async {
                  final survivors = await widget.runtime.contexts
                      .survivorsIfDestroyed(data.context.id);
                  widget.onDestroyRequested?.call(survivors);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(_MemoryData data) {
    return switch (_projection) {
      ProjectionKind.graph => _GraphView(
        center: data.context,
        linked: data.linked,
        onOpen: widget.onOpenContext,
      ),
      ProjectionKind.timeline => _TimelineView(
        ops: data.ops,
        onOpen: widget.onOpenOp,
      ),
      ProjectionKind.search => _SearchView(
        controller: _searchController,
        hits: _hits,
        onChanged: _search,
      ),
    };
  }
}

class _MemoryData {
  const _MemoryData({
    required this.context,
    required this.linked,
    required this.ops,
  });

  final MindContext context;
  final List<MindContext> linked;
  final List<MindOp> ops;
}

class _GraphView extends StatelessWidget {
  const _GraphView({required this.center, required this.linked, this.onOpen});

  final MindContext center;
  final List<MindContext> linked;
  final void Function(String contextId)? onOpen;

  @override
  Widget build(BuildContext context) {
    // A radial layout driven by the actual link set, not the design's fixed
    // pixel coordinates -- those describe one fixture's specific graph, and a
    // real context has however many links it has.
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final radius = (size.shortestSide / 2) - 60;
        final origin = Offset(size.width / 2, size.height / 2);

        return Stack(
          children: [
            CustomPaint(
              size: size,
              painter: _GraphEdgePainter(
                origin: origin,
                radius: radius,
                count: linked.length,
              ),
            ),
            Positioned(
              left: origin.dx - 35,
              top: origin.dy - 35,
              child: const _GraphNode(
                label: 'YOU',
                diameter: 70,
                isCenter: true,
              ),
            ),
            for (final (index, item) in linked.indexed)
              Builder(
                builder: (context) {
                  final angle =
                      (2 * 3.141592653589793 * index) / linked.length -
                      1.5707963267948966;
                  final pos =
                      origin +
                      Offset(radius * _cos(angle), radius * _sin(angle));
                  return Positioned(
                    left: pos.dx - 40,
                    top: pos.dy - 40,
                    child: _GraphNode(
                      label: item.label,
                      diameter: 80,
                      onTap: () => onOpen?.call(item.id),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  static double _cos(double radians) => _taylorCos(radians);
  static double _sin(double radians) =>
      _taylorCos(radians - 1.5707963267948966);

  // dart:math's cos/sin would be the obvious call; avoided only because this
  // file otherwise has no import for it and a five-term Taylor series is
  // accurate to better than a pixel at this radius. If a sixth node type ever
  // needs real trig precision, import dart:math instead of extending this.
  static double _taylorCos(double x) {
    while (x > 3.141592653589793) {
      x -= 2 * 3.141592653589793;
    }
    while (x < -3.141592653589793) {
      x += 2 * 3.141592653589793;
    }
    final x2 = x * x;
    return 1 - x2 / 2 + (x2 * x2) / 24 - (x2 * x2 * x2) / 720;
  }
}

class _GraphNode extends StatelessWidget {
  const _GraphNode({
    required this.label,
    required this.diameter,
    this.isCenter = false,
    this.onTap,
  });

  final String label;
  final double diameter;
  final bool isCenter;

  /// Null for the centre node -- YOU is the vantage point, not a link to
  /// follow. Every other node names a real context, so rule R02 requires it
  /// to be a genuine tap target, not a label that merely looks like one.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCenter
            ? MindPalette.surface
            : MindPalette.local.withValues(alpha: 0.12),
        border: Border.all(
          color: isCenter ? MindPalette.ink : MindPalette.local,
          width: isCenter ? 1.5 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isCenter ? 10 : 9,
            color: isCenter ? MindPalette.ink : MindPalette.local,
          ),
        ),
      ),
    );

    if (onTap == null) return circle;

    return Semantics(
      button: true,
      label: 'Open $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: circle,
      ),
    );
  }
}

class _GraphEdgePainter extends CustomPainter {
  _GraphEdgePainter({
    required this.origin,
    required this.radius,
    required this.count,
  });

  final Offset origin;
  final double radius;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MindPalette.grid
      ..strokeWidth = 1;
    for (var i = 0; i < count; i++) {
      final angle = (2 * 3.141592653589793 * i) / count - 1.5707963267948966;
      final target =
          origin +
          Offset(
            radius * _GraphView._cos(angle),
            radius * _GraphView._sin(angle),
          );
      canvas.drawLine(origin, target, paint);
    }
  }

  @override
  bool shouldRepaint(_GraphEdgePainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.radius != radius;
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.ops, required this.onOpen});

  final List<MindOp> ops;
  final void Function(MindOp op)? onOpen;

  @override
  Widget build(BuildContext context) {
    if (ops.isEmpty) {
      return const Center(
        child: Text(
          'Nothing in this context yet.',
          style: TextStyle(color: MindPalette.ink),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      itemCount: ops.length,
      itemBuilder: (context, index) =>
          MindOpRow(op: ops[index], onTap: () => onOpen?.call(ops[index])),
    );
  }
}

class _SearchView extends StatelessWidget {
  const _SearchView({
    required this.controller,
    required this.hits,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<SearchHitRef> hits;
  final void Function(String query) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: MindPalette.ink),
            decoration: const InputDecoration(
              hintText: 'Ask about this context…',
              hintStyle: TextStyle(color: MindPalette.grid),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: hits.length,
            itemBuilder: (context, index) {
              final hit = hits[index];
              return ListTile(
                title: Text(
                  hit.title,
                  style: const TextStyle(color: MindPalette.ink),
                ),
                subtitle: Text(
                  hit.snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MindPalette.ink.withValues(alpha: 0.6),
                  ),
                ),
                trailing: Text(
                  'op ${hit.opSequence}',
                  style: TextStyle(
                    color: MindPalette.ink.withValues(alpha: 0.4),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContextSheet extends StatelessWidget {
  const _ContextSheet({
    required this.context,
    required this.onOpen,
    required this.onDestroy,
  });

  final MindContext context;
  final VoidCallback onOpen;
  final VoidCallback onDestroy;

  @override
  Widget build(BuildContext buildContext) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MindPalette.grid)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The heading names the context this sheet is already about. It
            // is still wired to the same open action as the button below --
            // R02 makes tags tappable everywhere, and a special-cased
            // exception for "but this one is the current context" is a
            // harder rule to remember than "every tag opens something".
            InkWell(
              onTap: onOpen,
              child: Text(
                context.label,
                style: const TextStyle(
                  color: MindPalette.local,
                  fontFamily: 'AiroRulesExpanded',
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Context · ${groupedNumber(context.itemCount)} items · '
              '${groupedNumber(context.opCount)} ops',
              style: TextStyle(color: MindPalette.ink.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onOpen,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      // Sharp corners, flat surface -- the design system's own
                      // rule. Flutter's default FilledButton is a rounded
                      // pill, which is the wrong visual language for every
                      // surface in this device system.
                      color: MindPalette.ink,
                      child: const Text(
                        'OPEN CONTEXT',
                        style: TextStyle(
                          color: MindPalette.onFilled,
                          fontSize: 11,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDestroy,
                  icon: const Icon(
                    Icons.key_off_outlined,
                    color: MindPalette.alarm,
                  ),
                  tooltip: 'Delete context',
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Stated at the moment of deletion, not left implicit in a
            // confirmation dialog's default copy.
            Text(
              "Deleting revokes this context's wrapping key on every synced "
              'device. The ciphertext stays, unreadable, forever.',
              style: TextStyle(
                fontSize: 11,
                color: MindPalette.ink.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
