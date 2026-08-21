import 'package:flutter/material.dart';

import '../../domain/models/chat_entity_graph.dart';
import '../../domain/models/chat_transcript_turn.dart';
import '../../../provenance/domain/models/extracted_entity.dart';

/// Cursor-shaped sidebar: a knowledge directory (entity tree) above a
/// list of chats. Used by chat on desktop and by Memory GRAPH.
class MindDirectoryChatsPane extends StatelessWidget {
  const MindDirectoryChatsPane({
    super.key,
    required this.directory,
    required this.chats,
    this.activeChatId,
    this.onOpenChat,
    this.onNewChat,
    this.onOpenMemory,
  });

  final ChatEntityGraph directory;
  final List<MindChatRecord> chats;
  final String? activeChatId;
  final ValueChanged<String>? onOpenChat;
  final VoidCallback? onNewChat;
  final VoidCallback? onOpenMemory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _group(directory);

    return Material(
      key: const Key('mind.directory.chats.pane'),
      color: theme.colorScheme.surface.withValues(alpha: 0.72),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text('DIRECTORY', style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          if (grouped.isEmpty)
            Text(
              'Entities extracted from chat land here, like a file tree.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final entry in grouped.entries) ...[
              Text(entry.key, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              for (final node in entry.value)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('CHATS', style: theme.textTheme.labelSmall)),
              if (onNewChat != null)
                IconButton(
                  key: const Key('mind.chats.new'),
                  tooltip: 'New chat',
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: onNewChat,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (chats.isEmpty)
            Text(
              'Each chat is a folder with a JSONL transcript.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final chat in chats)
              ListTile(
                key: Key('mind.chats.row.${chat.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                selected: chat.id == activeChatId,
                title: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: chat.preview.isEmpty
                    ? null
                    : Text(
                        chat.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: onOpenChat == null ? null : () => onOpenChat!(chat.id),
              ),
          if (onOpenMemory != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('mind.memory.open'),
                onPressed: onOpenMemory,
                child: const Text('Open Memory graph'),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, List<ChatGraphNode>> _group(ChatEntityGraph graph) {
    final grouped = <String, List<ChatGraphNode>>{};
    for (final node in graph.nodes) {
      grouped.putIfAbsent(_folderName(node.type), () => []).add(node);
    }
    return grouped;
  }

  String _folderName(EntityType type) => switch (type) {
    EntityType.organization => 'organizations',
    EntityType.identifier => 'identifiers',
    EntityType.document => 'documents',
    EntityType.person => 'people',
    EntityType.date => 'dates',
    EntityType.term => 'terms',
  };
}
