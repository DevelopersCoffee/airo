import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../../application/providers/multiview_provider.dart';

/// Shown when adding a channel to MultiView would exceed capacity — lets
/// the viewer pick which currently-open screen to replace instead of just
/// failing. See [MultiviewController.replace] for the remove-then-add
/// sequencing this dialog triggers.
class MultiviewReplaceDialog extends StatelessWidget {
  const MultiviewReplaceDialog({
    super.key,
    required this.sessions,
    required this.onReplace,
  });

  final List<IptvMultiviewSession> sessions;

  /// The id of the session (== channel id, see [IptvMultiviewSession.id])
  /// to tear down and replace.
  final ValueChanged<String> onReplace;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('airo-tv-multiview-replace-dialog'),
      title: const Text('Replace which screen?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sessions.length; i++)
            TvFocusable(
              key: ValueKey('multiview-replace-slot-${sessions[i].id}'),
              semanticLabel: 'Screen ${i + 1}: ${sessions[i].channel.name}',
              onSelect: () {
                onReplace(sessions[i].id);
                Navigator.of(context).pop();
              },
              child: ListTile(
                title: Text('Screen ${i + 1}: ${sessions[i].channel.name}'),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

Future<void> showMultiviewReplaceDialog(
  BuildContext context, {
  required List<IptvMultiviewSession> sessions,
  required ValueChanged<String> onReplace,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        MultiviewReplaceDialog(sessions: sessions, onReplace: onReplace),
  );
}

/// Channel picker for filling a specific empty MultiView slot. Excludes
/// channels already open in another slot — [MultiviewController.toggle]
/// would otherwise treat picking one of those as "remove it," not "add it
/// here."
Future<void> showMultiviewEmptySlotPicker(
  BuildContext context, {
  required List<IPTVChannel> allChannels,
  required Set<String> excludeChannelIds,
  required ValueChanged<IPTVChannel> onSelected,
}) {
  final pickable = allChannels
      .where((channel) => !excludeChannelIds.contains(channel.id))
      .toList(growable: false);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: pickable.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No other channels available to add here.'),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: pickable.length,
              itemBuilder: (context, index) {
                final channel = pickable[index];
                return ListTile(
                  key: ValueKey('multiview-picker-${channel.id}'),
                  title: Text(channel.name),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onSelected(channel);
                  },
                );
              },
            ),
    ),
  );
}
