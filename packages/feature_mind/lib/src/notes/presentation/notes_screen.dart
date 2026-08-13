import 'package:flutter/material.dart';

import '../domain/note.dart';
import '../domain/notes_projection.dart';
import '../notes_capability.dart';

/// The minimal Notes screen: list + create/edit. `#1338`'s UI leg of the
/// runtime skeleton.
///
/// Renders from [NotesProjection], never from the operation log directly --
/// this widget never imports [NotesOperationLog]; the only way it sees
/// durable state is through [NotesCapability.notes]. Every mutation
/// (`create`/`edit`/`delete`) goes back through [NotesCapability] and the
/// screen reloads the projection afterward, rather than mutating local
/// widget state as if it were the source of truth.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.capability});

  final NotesCapability capability;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  NotesProjection _projection = NotesProjection.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final projection = await widget.capability.notes();
    if (!mounted) return;
    setState(() {
      _projection = projection;
      _loading = false;
    });
  }

  Future<void> _openEditor({Note? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final bodyController = TextEditingController(text: existing?.body ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'New note' : 'Edit note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              key: const Key('notes_screen_title_field'),
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: bodyController,
              key: const Key('notes_screen_body_field'),
              decoration: const InputDecoration(labelText: 'Body'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('notes_screen_save_button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing == null) {
      await widget.capability.createNote(
        id: 'note_$now',
        title: titleController.text,
        body: bodyController.text,
        recordedAtMs: now,
      );
    } else {
      await widget.capability.editNote(
        id: existing.id,
        title: titleController.text,
        body: bodyController.text,
        recordedAtMs: now,
      );
    }
    await _reload();
  }

  Future<void> _delete(Note note) async {
    await widget.capability.deleteNote(
      id: note.id,
      recordedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projection.isEmpty
          ? const Center(child: Text('No notes yet'))
          : ListView.builder(
              itemCount: _projection.all.length,
              itemBuilder: (context, index) {
                final note = _projection.all[index];
                return ListTile(
                  key: Key('notes_screen_note_${note.id}'),
                  title: Text(note.title),
                  subtitle: Text(note.body),
                  onTap: () => _openEditor(existing: note),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(note),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        key: const Key('notes_screen_create_button'),
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
