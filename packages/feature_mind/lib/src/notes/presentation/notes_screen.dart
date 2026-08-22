import 'package:flutter/material.dart';

import '../../notebook/application/notebook_repository.dart';
import '../../notebook/application/notebook_share_port.dart';
import '../../notebook/application/super_summary_recap_port.dart';
import '../../notebook/domain/notebook_document.dart';
import '../../notebook/domain/notebook_export.dart';
import '../../notebook/domain/notebook_l10n.dart';
import '../../notebook/domain/notebook_note.dart';
import '../../notebook/domain/notebook_search.dart';
import '../domain/note.dart';
import '../notes_capability.dart';

/// Notebook surface: list, search, tags, live/import actions, Super Summary,
/// and export / copy / share. Mutations still go through [NotesCapability]
/// (`#1338`); the extra fields live in the notebook document envelope.
class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.capability,
    this.sharePort,
    this.recapPort,
    this.onRecordLive,
    this.onImportAudio,
    this.onImportPodcast,
    this.onBack,
    this.localeCode = 'en',
  });

  final NotesCapability capability;
  final NotebookSharePort? sharePort;
  final SuperSummaryRecapPort? recapPort;
  final Future<void> Function()? onRecordLive;
  final Future<void> Function()? onImportAudio;
  final Future<void> Function()? onImportPodcast;
  final VoidCallback? onBack;
  final String localeCode;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final NotebookRepository _repository = NotebookRepository(
    widget.capability,
  );
  final _search = NotebookSearch();
  final _query = TextEditingController();

  List<NotebookNote> _notes = const [];
  bool _loading = true;
  bool _combining = false;
  bool _selecting = false;
  final Set<String> _selected = {};
  String? _tagFilter;

  NotebookL10n get _l10n => NotebookL10n.of(widget.localeCode);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final notes = await _repository.all();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
      _selected.removeWhere((id) => notes.every((note) => note.id != id));
    });
  }

  List<NotebookNote> get _visible {
    return _search.filter(
      notes: _notes,
      query: _query.text,
      tags: {?_tagFilter},
    );
  }

  List<String> get _allTags {
    final seen = <String>{};
    final tags = <String>[];
    for (final note in _notes) {
      for (final tag in note.document.tags) {
        if (seen.add(tag.toLowerCase())) tags.add(tag);
      }
    }
    tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  Future<void> _openEditor({NotebookNote? existing, Note? legacy}) async {
    final l10n = _l10n;
    final current =
        existing ?? (legacy == null ? null : NotebookNote.fromNote(legacy));
    final titleController = TextEditingController(text: current?.title ?? '');
    final bodyController = TextEditingController(
      text: current?.document.body ?? '',
    );
    final tagsController = TextEditingController(
      text: current?.document.tags.join(', ') ?? '',
    );
    final labelsController = TextEditingController(
      text: current?.document.labels.join(', ') ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(current == null ? l10n.newNote : l10n.editNote),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                key: const Key('notes_screen_title_field'),
                decoration: InputDecoration(labelText: l10n.title),
              ),
              TextField(
                controller: bodyController,
                key: const Key('notes_screen_body_field'),
                decoration: InputDecoration(labelText: l10n.body),
                maxLines: 3,
              ),
              TextField(
                controller: tagsController,
                key: const Key('notes_screen_tags_field'),
                decoration: InputDecoration(
                  labelText: l10n.tags,
                  hintText: l10n.tagsHint,
                ),
              ),
              TextField(
                controller: labelsController,
                key: const Key('notes_screen_labels_field'),
                decoration: InputDecoration(
                  labelText: l10n.labels,
                  hintText: l10n.labelsHint,
                ),
              ),
              if (current != null && current.document.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.summary,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(current.document.summary),
              ],
              if (current != null && current.document.keyPoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.keyPoints,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final point in current.document.keyPoints)
                  Text('• $point'),
              ],
            ],
          ),
        ),
        actions: [
          if (current != null && widget.sharePort != null)
            IconButton(
              key: const Key('notes_screen_copy_button'),
              tooltip: l10n.copy,
              onPressed: () => _copy(current),
              icon: const Icon(Icons.copy_outlined),
            ),
          if (current != null && widget.sharePort != null)
            IconButton(
              key: const Key('notes_screen_share_button'),
              tooltip: l10n.share,
              onPressed: () => _share(current),
              icon: const Icon(Icons.ios_share),
            ),
          if (current != null && widget.sharePort != null)
            IconButton(
              key: const Key('notes_screen_export_button'),
              tooltip: l10n.export,
              onPressed: () => _export(current),
              icon: const Icon(Icons.save_alt),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('notes_screen_save_button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final document = (current?.document ?? const NotebookDocument()).copyWith(
      body: bodyController.text,
      tags: _csv(tagsController.text),
      labels: _csv(labelsController.text),
    );
    await _repository.save(
      id: current?.id ?? 'note_$now',
      title: titleController.text,
      document: document,
      recordedAtMs: now,
      exists: current != null,
    );
    await _reload();
  }

  List<String> _csv(String raw) => [
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  Future<void> _delete(NotebookNote note) async {
    await _repository.delete(
      id: note.id,
      recordedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _reload();
  }

  Future<void> _copy(NotebookNote note) async {
    final port = widget.sharePort;
    if (port == null) return;
    await port.copyText(renderNotebookMarkdown(note));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_l10n.copied)));
  }

  Future<void> _share(NotebookNote note) async {
    final port = widget.sharePort;
    if (port == null) return;
    final ok = await port.shareMarkdown(
      filename: notebookExportFileName(note),
      markdown: renderNotebookMarkdown(note),
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_l10n.shared)));
  }

  Future<void> _export(NotebookNote note) async {
    final port = widget.sharePort;
    if (port == null) return;
    final ok = await port.saveMarkdown(
      filename: notebookExportFileName(note),
      markdown: renderNotebookMarkdown(note),
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_l10n.saved)));
  }

  Future<void> _combineSelected() async {
    final selected = [
      for (final note in _notes)
        if (_selected.contains(note.id)) note,
    ];
    if (selected.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.needsTwoNotes)));
      return;
    }
    String? generatedRecap;
    setState(() => _combining = true);
    try {
      try {
        generatedRecap = await widget.recapPort?.generate(selected);
      } on Object {
        generatedRecap = null;
      }
      if (!mounted) return;
      await _repository.superSummary(
        notes: selected,
        recordedAtMs: DateTime.now().millisecondsSinceEpoch,
        generatedRecap: generatedRecap,
      );
    } finally {
      if (mounted) {
        setState(() {
          _combining = false;
          _selecting = false;
          _selected.clear();
        });
      }
    }
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final visible = _visible;
    final rtl = widget.localeCode == 'ar';

    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.notesTitle),
          leading: widget.onBack == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
          actions: [
            if (widget.onRecordLive != null)
              IconButton(
                key: const Key('notes_screen_record_button'),
                tooltip: l10n.record,
                onPressed: widget.onRecordLive,
                icon: const Icon(Icons.mic_none),
              ),
            if (widget.onImportAudio != null)
              IconButton(
                key: const Key('notes_screen_import_audio_button'),
                tooltip: l10n.importAudio,
                onPressed: widget.onImportAudio,
                icon: const Icon(Icons.upload_file),
              ),
            if (widget.onImportPodcast != null)
              IconButton(
                key: const Key('notes_screen_import_podcast_button'),
                tooltip: l10n.importPodcast,
                onPressed: widget.onImportPodcast,
                icon: const Icon(Icons.podcasts),
              ),
            IconButton(
              key: const Key('notes_screen_super_summary_button'),
              tooltip: l10n.superSummary,
              onPressed: () {
                setState(() {
                  _selecting = !_selecting;
                  if (!_selecting) _selected.clear();
                });
              },
              icon: Icon(_selecting ? Icons.close : Icons.auto_awesome),
            ),
            if (_selecting)
              IconButton(
                key: const Key('notes_screen_combine_button'),
                tooltip: l10n.combineSelected,
                onPressed: _combining ? null : _combineSelected,
                icon: const Icon(Icons.merge_type),
              ),
          ],
        ),
        body: _loading || _combining
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (_combining) ...[
                      const SizedBox(height: 16),
                      Text(l10n.generatingSuperSummary),
                    ],
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextField(
                      key: const Key('notes_screen_search_field'),
                      controller: _query,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.search,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_allTags.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView(
                        key: const Key('notes_screen_tag_filter'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        children: [
                          for (final tag in _allTags)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                key: Key('notes_screen_tag_chip_$tag'),
                                label: Text(tag),
                                selected: _tagFilter == tag,
                                onSelected: (selected) {
                                  setState(
                                    () => _tagFilter = selected ? tag : null,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _notes.isEmpty
                        ? Center(child: Text(l10n.noNotesYet))
                        : visible.isEmpty
                        ? Center(child: Text(l10n.noMatchingNotes))
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final note = visible[index];
                              final selected = _selected.contains(note.id);
                              return ListTile(
                                key: Key('notes_screen_note_${note.id}'),
                                leading: _selecting
                                    ? Checkbox(
                                        value: selected,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value ?? false) {
                                              _selected.add(note.id);
                                            } else {
                                              _selected.remove(note.id);
                                            }
                                          });
                                        },
                                      )
                                    : null,
                                title: Text(note.title),
                                subtitle: _subtitle(note),
                                onTap: () {
                                  if (_selecting) {
                                    setState(() {
                                      if (selected) {
                                        _selected.remove(note.id);
                                      } else {
                                        _selected.add(note.id);
                                      }
                                    });
                                    return;
                                  }
                                  _openEditor(existing: note);
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: l10n.delete,
                                  onPressed: () => _delete(note),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          key: const Key('notes_screen_create_button'),
          onPressed: () => _openEditor(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _subtitle(NotebookNote note) {
    final preview = note.preview;
    final chips = [...note.document.tags, ...note.document.labels];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.isNotEmpty) Text(preview, maxLines: 2),
        if (chips.isNotEmpty)
          Wrap(
            spacing: 4,
            children: [
              for (final chip in chips.take(4))
                Chip(
                  label: Text(chip),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
      ],
    );
  }
}
