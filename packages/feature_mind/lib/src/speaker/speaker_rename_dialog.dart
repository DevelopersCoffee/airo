import 'package:flutter/material.dart';

import '../mind_diarization.dart';
import '../speaker/meeting_speaker_registry.dart';

/// Dialog to rename a diarized speaker label for one meeting.
Future<String?> showSpeakerRenameDialog({
  required BuildContext context,
  required String speakerLabel,
  MeetingSpeakerRegistry registry = MeetingSpeakerRegistry.empty,
}) async {
  final initial = mindSpeakerDisplayLabel(speakerLabel, registry: registry);
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename speaker'),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Display name',
          hintText: formatMindSpeakerLabel(speakerLabel),
        ),
        autofocus: true,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Pick which speaker label merged segments should display as.
Future<String?> showSpeakerMergeDialog({
  required BuildContext context,
  required String fromLabel,
  required List<String> candidateLabels,
  MeetingSpeakerRegistry registry = MeetingSpeakerRegistry.empty,
}) async {
  final targets = [
    for (final label in candidateLabels)
      if (label != fromLabel) label,
  ];
  if (targets.isEmpty) return null;
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(
        'Merge ${formatMindSpeakerLabel(fromLabel)} into…',
      ),
      children: [
        for (final label in targets)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(label),
            child: Text(mindSpeakerDisplayLabel(label, registry: registry)),
          ),
      ],
    ),
  );
}
