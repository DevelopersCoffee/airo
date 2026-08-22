import 'package:flutter/material.dart';

import '../runtime/models/log_models.dart';
import '../widgets/grouped_number.dart';
import '../widgets/mind_palette.dart';
import 'runtime_console_availability.dart';
import 'runtime_console_controller.dart';
import 'runtime_console_models.dart';

/// Surface 13, Windows/Linux: the append-only log as an operator's table.
///
/// Every row is signed and attributed to the device that wrote it. The table
/// is virtualised — [ListView.builder] plus [RuntimeConsoleController]'s
/// paging — because the design shows 9 of 12,481 rows with scroll-or-filter,
/// not a table that renders all of them.
///
/// Right-click a row to replay the log from that point; this calls
/// [RuntimeConsoleController.replayFrom], a real operation against
/// [OperationLogPort], not a view filter.
class RuntimeConsoleTable extends StatefulWidget {
  const RuntimeConsoleTable({
    super.key,
    required this.controller,
    this.platformOverride,
  });

  final RuntimeConsoleController controller;

  /// Overrides the platform gate for tests. Production callers leave this
  /// null and get [defaultTargetPlatform].
  final TargetPlatform? platformOverride;

  @override
  State<RuntimeConsoleTable> createState() => _RuntimeConsoleTableState();
}

class _RuntimeConsoleTableState extends State<RuntimeConsoleTable> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (isRuntimeConsolePlatform(widget.platformOverride)) {
      widget.controller.loadInitial();
    }
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isRuntimeConsolePlatform(widget.platformOverride)) {
      return const _ConsoleUnavailable();
    }
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        if (controller.loadError != null) {
          return _ConsoleError(error: controller.loadError!);
        }
        return Column(
          children: [
            _RuntimeConsoleHeader(controller: controller),
            const Divider(height: 1),
            Expanded(
              child: controller.loadedCount == 0 && controller.isLoadingPage
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      key: const Key('mind.console.list'),
                      controller: _scroll,
                      itemCount:
                          controller.rows.length + (controller.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= controller.rows.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        final op = controller.rows[index];
                        return _RuntimeConsoleRow(
                          controller: controller,
                          op: op,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ConsoleUnavailable extends StatelessWidget {
  const _ConsoleUnavailable();

  @override
  Widget build(BuildContext context) => const Center(
    key: Key('mind.console.unavailable'),
    child: Text('The Runtime Console runs on Windows and Linux.'),
  );
}

class _ConsoleError extends StatelessWidget {
  const _ConsoleError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('mind.console.error'),
    child: Text('The runtime log is unavailable: $error'),
  );
}

class _RuntimeConsoleHeader extends StatelessWidget {
  const _RuntimeConsoleHeader({required this.controller});

  final RuntimeConsoleController controller;

  static const Map<RuntimeConsoleSortField, String> _labels = {
    RuntimeConsoleSortField.sequence: 'Op',
    RuntimeConsoleSortField.time: 'Time',
    RuntimeConsoleSortField.kind: 'Type',
    RuntimeConsoleSortField.title: 'Title',
    RuntimeConsoleSortField.device: 'Device',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final field in RuntimeConsoleSortField.values)
            Expanded(
              flex: field == RuntimeConsoleSortField.title ? 3 : 1,
              child: _SortableHeaderCell(
                label: _labels[field]!,
                isActive: controller.sortField == field,
                direction: controller.sortDirection,
                onTap: () => controller.sortBy(field),
              ),
            ),
          const Expanded(
            child: Text(
              'Context',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const Expanded(
            child: Text(
              'Signature',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortableHeaderCell extends StatelessWidget {
  const _SortableHeaderCell({
    required this.label,
    required this.isActive,
    required this.direction,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final RuntimeConsoleSortDirection direction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? MindPalette.local : null,
            ),
          ),
          if (isActive)
            Icon(
              direction == RuntimeConsoleSortDirection.ascending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 12,
              color: MindPalette.local,
            ),
        ],
      ),
    );
  }
}

class _RuntimeConsoleRow extends StatelessWidget {
  const _RuntimeConsoleRow({required this.controller, required this.op});

  final RuntimeConsoleController controller;
  final MindOp op;

  static const Map<MindOpKind, String> _kindLabels = {
    MindOpKind.note: 'note',
    MindOpKind.scan: 'scan',
    MindOpKind.voice: 'voice',
    MindOpKind.transcript: 'transcript',
    MindOpKind.inference: 'inference',
    MindOpKind.automation: 'automation',
    MindOpKind.merge: 'merge',
    MindOpKind.revoke: 'revoke',
    MindOpKind.import: 'import',
    MindOpKind.consent: 'consent',
    MindOpKind.consentRevoked: 'consent revoked',
    MindOpKind.meetingIrExtracted: 'meeting IR extracted',
    MindOpKind.speakerEnrolled: 'speaker enrolled',
    MindOpKind.researchCheckpoint: 'research checkpoint',
    MindOpKind.researchLibrary: 'research library',
  };

  static const Map<SignatureState, String> _signatureLabels = {
    SignatureState.verified: 'verified',
    SignatureState.unverified: 'UNVERIFIED',
    SignatureState.unsigned: 'UNSIGNED',
  };

  static final Map<SignatureState, Color> _signatureColours = {
    SignatureState.verified: MindPalette.ink.withValues(alpha: 0.6),
    SignatureState.unverified: MindPalette.alarm,
    SignatureState.unsigned: MindPalette.remote,
  };

  @override
  Widget build(BuildContext context) {
    final signature = controller.signatureFor(op);
    final replaying = controller.isReplaying(op.sequence);
    final progress = controller.replayProgressFor(op.sequence);

    return GestureDetector(
      key: Key('mind.console.row.${op.sequence}'),
      onSecondaryTapDown: (_) => controller.replayFrom(op.sequence),
      child: Container(
        color: replaying
            ? MindPalette.local.withValues(alpha: 0.08)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'op ${groupedNumber(op.sequence)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    DateTime.fromMillisecondsSinceEpoch(
                      op.recordedAtMs,
                    ).toIso8601String(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    _kindLabels[op.kind]!,
                    key: Key('mind.console.type.${op.sequence}'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    op.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    op.deviceName,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    op.contextId.isEmpty ? '—' : op.contextId,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _signatureLabels[signature]!,
                          key: Key('mind.console.signature.${op.sequence}'),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _signatureColours[signature],
                            fontWeight: signature == SignatureState.verified
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        key: Key('mind.console.verify.${op.sequence}'),
                        onTap: controller.isVerifying(op.sequence)
                            ? null
                            : () => controller.verifyRow(op.sequence),
                        child: controller.isVerifying(op.sequence)
                            ? const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  key: Key('mind.console.replay.${op.sequence}'),
                  children: [
                    Expanded(child: LinearProgressIndicator(value: progress)),
                    const SizedBox(width: 8),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
