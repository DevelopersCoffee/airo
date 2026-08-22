import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../runtime/mind_runtime.dart';
import '../runtime/models/context_models.dart';
import '../runtime/models/log_models.dart';
import '../runtime/models/projection_models.dart';
import 'grouped_number.dart';
import 'mind_context_chip.dart';
import 'mind_number_strip.dart';
import 'mind_palette.dart';
import 'mind_presence_pip.dart';

/// One extracted or provenance field in the preview column.
///
/// [isInferred] distinguishes a field the runtime guessed from one a person
/// actually filed — the design's own example is a category that was
/// "inferred, not filed", and rendering both the same way is the failure this
/// exists to prevent.
@immutable
class MindPreviewField {
  const MindPreviewField({
    required this.label,
    required this.value,
    this.isInferred = false,
  });

  final String label;
  final String value;
  final bool isInferred;
}

/// Surface 11. The macOS Everything Browser: search the whole log, three
/// columns, ranked locally.
///
/// Library and contexts on the left, ranked results in the centre, the
/// selected result's provenance on the right — the design's own layout.
/// macOS only: Mac conventions supply the chrome (this widget expects to sit
/// under a native menu bar; see [MindNativeMenuBar] and
/// [MindCommandPaletteScope]), while the interior keeps the flat grid-line
/// language the phone surfaces use.
class MindEverythingBrowser extends StatefulWidget {
  const MindEverythingBrowser({super.key, required this.runtime, this.onClose});

  final MindRuntime runtime;

  /// Null when the browser is not shown as a dismissible overlay — for
  /// example a Window-menu destination that isn't in a dialog.
  final VoidCallback? onClose;

  /// Whether this platform gets the Everything Browser at all.
  ///
  /// A shell composes this widget only on macOS, but the widget guards itself
  /// too: a caller that renders it on the wrong platform by mistake gets a
  /// truthful "not here" rather than a broken three-column layout squeezed
  /// onto a phone.
  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  State<MindEverythingBrowser> createState() => _MindEverythingBrowserState();
}

class _MindEverythingBrowserState extends State<MindEverythingBrowser> {
  final _searchController = TextEditingController();

  List<MindContext> _contexts = const [];
  String? _selectedContextId;

  List<SearchHitRef> _hits = const [];
  SearchHitRef? _selectedHit;
  MindOp? _selectedOp;

  int _latencyMs = 0;
  bool _searching = false;

  /// Names the port, per `MindPortUnavailable`'s own contract: "the mesh is
  /// not implemented yet" tells a person the rest of the app works.
  String? _unavailableReason;

  ProjectionState? _searchProjection;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contexts = await widget.runtime.contexts.all();
      final projection = await widget.runtime.projections.stateOf(
        ProjectionKind.search,
      );
      if (!mounted) return;
      setState(() {
        _contexts = contexts;
        _searchProjection = projection;
      });
      await _runSearch('');
    } on MindPortUnavailable catch (error) {
      if (!mounted) return;
      setState(() => _unavailableReason = error.toString());
    }
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final stopwatch = Stopwatch()..start();
      final hits = await widget.runtime.projections.search(
        query,
        contextId: _selectedContextId,
      );
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _latencyMs = stopwatch.elapsedMilliseconds;
        _searching = false;
        _unavailableReason = null;
        _selectedHit = hits.isEmpty ? null : hits.first;
      });
      await _loadSelectedOp();
    } on MindPortUnavailable catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _hits = const [];
        _selectedHit = null;
        _selectedOp = null;
        _unavailableReason = error.toString();
      });
    }
  }

  Future<void> _loadSelectedOp() async {
    final hit = _selectedHit;
    if (hit == null) {
      setState(() => _selectedOp = null);
      return;
    }
    final op = await widget.runtime.log.bySequence(hit.opSequence);
    if (!mounted) return;
    setState(() => _selectedOp = op);
  }

  void _selectContext(String? contextId) {
    setState(
      () => _selectedContextId = _selectedContextId == contextId
          ? null
          : contextId,
    );
    unawaited(_runSearch(_searchController.text));
  }

  void _selectHit(SearchHitRef hit) {
    setState(() => _selectedHit = hit);
    unawaited(_loadSelectedOp());
  }

  @override
  Widget build(BuildContext context) {
    if (!MindEverythingBrowser.isSupportedPlatform) {
      return const Center(
        key: Key('mind.everythingBrowser.unsupported'),
        child: Text('The Everything Browser is a macOS surface.'),
      );
    }

    return Material(
      color: MindPalette.onFilled,
      child: SafeArea(
        child: Column(
          children: [
            _TopBar(
              controller: _searchController,
              onChanged: (value) => unawaited(_runSearch(value)),
              onClose: widget.onClose,
            ),
            if (_unavailableReason != null)
              _UnavailableBanner(reason: _unavailableReason!)
            else if (_searchProjection?.status == ProjectionStatus.rebuilding)
              _RebuildingBanner(state: _searchProjection!)
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _LibraryColumn(
                        contexts: _contexts,
                        selectedContextId: _selectedContextId,
                        onSelect: _selectContext,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 3,
                      child: _ResultsColumn(
                        hits: _hits,
                        selected: _selectedHit,
                        loading: _searching,
                        query: _searchController.text,
                        latencyMs: _latencyMs,
                        onSelect: _selectHit,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 3,
                      child: _PreviewColumn(
                        hit: _selectedHit,
                        op: _selectedOp,
                        contexts: _contexts,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: MindNumberStrip(
                opCount: _searchProjection?.opsTotal ?? 0,
                peerCount: 0,
                vaultSealed: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          const MindPresencePip(isLocal: true),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('mind.everythingBrowser.searchField'),
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              style: const TextStyle(color: MindPalette.ink),
              decoration: const InputDecoration(
                hintText: 'Search everything…',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 8),
            IconButton(
              key: const Key('mind.everythingBrowser.close'),
              icon: const Icon(Icons.close, color: MindPalette.ink),
              onPressed: onClose,
            ),
          ],
        ],
      ),
    );
  }
}

class _UnavailableBanner extends StatelessWidget {
  const _UnavailableBanner({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            reason,
            key: const Key('mind.everythingBrowser.unavailable'),
            textAlign: TextAlign.center,
            style: TextStyle(color: MindPalette.ink.withValues(alpha: 0.8)),
          ),
        ),
      ),
    );
  }
}

class _RebuildingBanner extends StatelessWidget {
  const _RebuildingBanner({required this.state});

  final ProjectionState state;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: MindPalette.local),
              const SizedBox(height: 12),
              Text(
                'Rebuilding the search index — '
                '${groupedNumber(state.opsProcessed)} / '
                '${groupedNumber(state.opsTotal)} ops',
                key: const Key('mind.everythingBrowser.rebuilding'),
                style: const TextStyle(color: MindPalette.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryColumn extends StatelessWidget {
  const _LibraryColumn({
    required this.contexts,
    required this.selectedContextId,
    required this.onSelect,
  });

  final List<MindContext> contexts;
  final String? selectedContextId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTEXTS',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              color: MindPalette.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          // R02: chips wrap rather than sit in a bare Row. A narrow column —
          // this one included, third of a three-way split — clips or
          // overflows a Row the moment the labels no longer fit one line.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mindContext in contexts)
                MindContextChip(
                  context: mindContext,
                  isSelected: mindContext.id == selectedContextId,
                  onTap: () => onSelect(mindContext.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultsColumn extends StatelessWidget {
  const _ResultsColumn({
    required this.hits,
    required this.selected,
    required this.loading,
    required this.query,
    required this.latencyMs,
    required this.onSelect,
  });

  final List<SearchHitRef> hits;
  final SearchHitRef? selected;
  final bool loading;
  final String query;
  final int latencyMs;
  final ValueChanged<SearchHitRef> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : hits.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty
                        ? 'No results yet.'
                        : 'No matches for "$query".',
                    key: const Key('mind.everythingBrowser.emptyResults'),
                    style: TextStyle(
                      color: MindPalette.ink.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: hits.length,
                  itemBuilder: (context, index) {
                    final hit = hits[index];
                    final isSelected = hit == selected;
                    return ListTile(
                      selected: isSelected,
                      onTap: () => onSelect(hit),
                      title: Text(
                        hit.title,
                        style: const TextStyle(color: MindPalette.ink),
                      ),
                      subtitle: Text(
                        hit.snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MindPalette.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${hits.length} HITS · $latencyMs MS',
                key: const Key('mind.everythingBrowser.hitCount'),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: MindPalette.ink.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Nothing is sent anywhere.',
                style: TextStyle(
                  fontSize: 10,
                  color: MindPalette.ink.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewColumn extends StatelessWidget {
  const _PreviewColumn({
    required this.hit,
    required this.op,
    required this.contexts,
  });

  final SearchHitRef? hit;
  final MindOp? op;
  final List<MindContext> contexts;

  static const Map<SignatureState, String> _signatureLabels = {
    SignatureState.verified: 'verified',
    SignatureState.unverified: 'UNVERIFIED',
    SignatureState.unsigned: 'UNSIGNED',
  };

  List<MindPreviewField> _fieldsFor(MindOp op) {
    final links = contexts
        .where((c) => hit?.contextIds.contains(c.id) ?? false)
        .map((c) => c.label)
        .toList(growable: false);
    return [
      MindPreviewField(label: 'Recorded by', value: op.deviceName),
      if (op.detail.isNotEmpty)
        MindPreviewField(label: 'Detail', value: op.detail),
      // The kind is a classification the runtime assigned, not one a person
      // filed — the design's own copy is explicit that this is inferred.
      MindPreviewField(
        label: 'Category',
        value: op.kind.name,
        isInferred: true,
      ),
      MindPreviewField(
        label: 'Hypergraph links',
        value: links.isEmpty ? 'None' : links.join(', '),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (hit == null || op == null) {
      return Center(
        child: Text(
          'Select a result to see its provenance.',
          key: const Key('mind.everythingBrowser.noPreview'),
          style: TextStyle(color: MindPalette.ink.withValues(alpha: 0.6)),
        ),
      );
    }

    final currentOp = op!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'op ${groupedNumber(currentOp.sequence)}',
            key: const Key('mind.everythingBrowser.opNumber'),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              color: MindPalette.local,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _signatureLabels[currentOp.signature]!,
            key: const Key('mind.everythingBrowser.signatureState'),
            style: const TextStyle(fontSize: 12, color: MindPalette.ink),
          ),
          const SizedBox(height: 12),
          for (final field in _fieldsFor(currentOp))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.isInferred
                        ? '${field.label} (inferred)'
                        : field.label,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontStyle: field.isInferred
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: field.isInferred
                          ? MindPalette.remote
                          : MindPalette.ink.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    field.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: field.isInferred
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: MindPalette.ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
