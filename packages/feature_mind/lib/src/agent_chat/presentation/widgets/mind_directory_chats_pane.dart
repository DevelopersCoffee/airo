import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/chat_entity_graph.dart';
import '../../domain/models/chat_transcript_turn.dart';
import '../../../provenance/domain/models/extracted_entity.dart';

/// Cursor-shaped sidebar: a knowledge directory (entity tree) above a
/// list of chats grouped into folders that share that folder's KV.
class MindDirectoryChatsPane extends StatelessWidget {
  const MindDirectoryChatsPane({
    super.key,
    required this.directory,
    required this.chats,
    this.folders = const [],
    this.activeChatId,
    this.activeFolderId,
    this.onOpenChat,
    this.onNewChat,
    this.onOpenMemory,
    this.onCreateFolder,
    this.onMoveChat,
    this.onRemoveChat,
    this.onNewChatInFolder,
    this.onSetFolderPlugins,
    this.onBrowseAddOns,
    this.pluginOptions = const [],
  });

  final ChatEntityGraph directory;
  final List<MindChatRecord> chats;
  final List<MindChatFolder> folders;
  final String? activeChatId;
  final String? activeFolderId;
  final ValueChanged<String>? onOpenChat;
  final VoidCallback? onNewChat;
  final VoidCallback? onOpenMemory;
  final ValueChanged<String>? onCreateFolder;
  final void Function(String chatId, String? folderId)? onMoveChat;
  final ValueChanged<String>? onRemoveChat;
  final ValueChanged<String>? onNewChatInFolder;
  final void Function(String folderId, List<String> pluginIds)?
  onSetFolderPlugins;
  final VoidCallback? onBrowseAddOns;
  final List<MindFolderPluginOption> pluginOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _group(directory);
    final unfiled = chats.where((chat) => chat.folderId == null).toList();

    return Material(
      key: const Key('mind.directory.chats.pane'),
      color: theme.colorScheme.surface.withValues(alpha: 0.72),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(
            activeFolderId == null
                ? 'DIRECTORY'
                : 'DIRECTORY · ${_folderName(activeFolderId)}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 16),
          if (grouped.isEmpty)
            Text(
              activeFolderId == null
                  ? 'Entities extracted from chat land here, like a file tree.'
                  : 'Chats in this folder share this knowledge.',
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
              if (onCreateFolder != null)
                IconButton(
                  key: const Key('mind.chats.new_folder'),
                  tooltip: 'New folder',
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  onPressed: () => unawaited(_promptNewFolder(context)),
                  visualDensity: VisualDensity.compact,
                ),
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
          if (chats.isEmpty && folders.isEmpty)
            Text(
              'Each chat is a folder with a JSONL transcript.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            for (final folder in folders)
              _FolderBlock(
                folder: folder,
                chats: chats
                    .where((chat) => chat.folderId == folder.id)
                    .toList(),
                activeChatId: activeChatId,
                onOpenChat: onOpenChat,
                onMoveChat: onMoveChat,
                onRemoveChat: onRemoveChat,
                onNewChatInFolder: onNewChatInFolder,
                onSetFolderPlugins: onSetFolderPlugins,
                onBrowseAddOns: onBrowseAddOns,
                pluginOptions: pluginOptions,
                folders: folders,
              ),
            for (final chat in unfiled)
              _ChatTile(
                chat: chat,
                selected: chat.id == activeChatId,
                folders: folders,
                onOpenChat: onOpenChat,
                onMoveChat: onMoveChat,
                onRemoveChat: onRemoveChat,
              ),
          ],
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

  String _folderName(String? id) {
    for (final folder in folders) {
      if (folder.id == id) return folder.name;
    }
    return 'folder';
  }

  Future<void> _promptNewFolder(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          key: const Key('mind.chats.new_folder.name'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('mind.chats.new_folder.create'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    onCreateFolder!(name);
  }

  Map<String, List<ChatGraphNode>> _group(ChatEntityGraph graph) {
    final grouped = <String, List<ChatGraphNode>>{};
    for (final node in graph.nodes) {
      grouped.putIfAbsent(_entityFolderName(node.type), () => []).add(node);
    }
    return grouped;
  }

  String _entityFolderName(EntityType type) => switch (type) {
    EntityType.organization => 'organizations',
    EntityType.identifier => 'identifiers',
    EntityType.document => 'documents',
    EntityType.person => 'people',
    EntityType.date => 'dates',
    EntityType.term => 'terms',
    EntityType.location => 'locations',
    EntityType.money => 'amounts',
  };
}

class _FolderBlock extends StatelessWidget {
  const _FolderBlock({
    required this.folder,
    required this.chats,
    required this.folders,
    required this.pluginOptions,
    this.activeChatId,
    this.onOpenChat,
    this.onMoveChat,
    this.onRemoveChat,
    this.onNewChatInFolder,
    this.onSetFolderPlugins,
    this.onBrowseAddOns,
  });

  final MindChatFolder folder;
  final List<MindChatRecord> chats;
  final List<MindChatFolder> folders;
  final List<MindFolderPluginOption> pluginOptions;
  final String? activeChatId;
  final ValueChanged<String>? onOpenChat;
  final void Function(String chatId, String? folderId)? onMoveChat;
  final ValueChanged<String>? onRemoveChat;
  final ValueChanged<String>? onNewChatInFolder;
  final void Function(String folderId, List<String> pluginIds)?
  onSetFolderPlugins;
  final VoidCallback? onBrowseAddOns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pluginNames = [
      for (final id in folder.pluginIds)
        for (final option in pluginOptions)
          if (option.id == id) option.name,
    ];
    final subtitle = pluginNames.isEmpty
        ? 'Shared knowledge'
        : 'Assisted by ${pluginNames.join(', ')}';

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          onMoveChat != null && details.data != folder.id,
      onAcceptWithDetails: (details) {
        if (details.data.isEmpty) return;
        onMoveChat?.call(details.data, folder.id);
      },
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Material(
          color: hovering
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: hovering ? theme.colorScheme.primary : Colors.transparent,
            ),
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: Key('mind.chats.folder.${folder.id}'),
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined, size: 18),
              title: Text(
                folder.name,
                key: Key('mind.chats.folder.${folder.id}.drop'),
              ),
              subtitle: Text(subtitle),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onNewChatInFolder != null)
                    IconButton(
                      key: Key('mind.chats.folder.${folder.id}.new'),
                      tooltip: 'New chat in ${folder.name}',
                      icon: const Icon(Icons.add, size: 20),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => onNewChatInFolder!(folder.id),
                    ),
                  if (onSetFolderPlugins != null)
                    IconButton(
                      key: Key('mind.chats.folder.${folder.id}.plugins'),
                      tooltip: 'Folder add-ons',
                      icon: const Icon(Icons.extension_outlined, size: 20),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => unawaited(_editAddOns(context)),
                    ),
                ],
              ),
              children: [
                for (final chat in chats)
                  _ChatTile(
                    chat: chat,
                    selected: chat.id == activeChatId,
                    folders: folders,
                    indent: true,
                    onOpenChat: onOpenChat,
                    onMoveChat: onMoveChat,
                    onRemoveChat: onRemoveChat,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editAddOns(BuildContext context) async {
    final selected = {...folder.pluginIds};
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final empty = pluginOptions.isEmpty;
            return AlertDialog(
              title: Text('Add-ons for ${folder.name}'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: empty
                    ? const _AddOnsEmptyState()
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Attach installed skills to every chat in this folder.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            for (final plugin in pluginOptions)
                              CheckboxListTile(
                                key: Key(
                                  'mind.chats.folder.${folder.id}.plugin.${plugin.id}',
                                ),
                                value: selected.contains(plugin.id),
                                contentPadding: EdgeInsets.zero,
                                title: Text(plugin.name),
                                subtitle: plugin.description.isEmpty
                                    ? null
                                    : Text(
                                        plugin.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                onChanged: (value) {
                                  setLocal(() {
                                    if (value == true) {
                                      selected.add(plugin.id);
                                    } else {
                                      selected.remove(plugin.id);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                if (onBrowseAddOns != null && empty)
                  FilledButton(
                    key: Key('mind.chats.folder.${folder.id}.addons.browse'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onBrowseAddOns!();
                    },
                    child: const Text('Browse add-ons'),
                  ),
                if (onBrowseAddOns != null && !empty)
                  TextButton(
                    key: Key('mind.chats.folder.${folder.id}.addons.browse'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onBrowseAddOns!();
                    },
                    child: const Text('Browse more'),
                  ),
                if (!empty)
                  FilledButton(
                    key: Key('mind.chats.folder.${folder.id}.plugins.save'),
                    onPressed: () =>
                        Navigator.of(context).pop(selected.toList()),
                    child: const Text('Save'),
                  ),
              ],
            );
          },
        );
      },
    );
    if (result != null) onSetFolderPlugins!(folder.id, result);
  }
}

class _AddOnsEmptyState extends StatelessWidget {
  const _AddOnsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.extension_outlined,
          size: 32,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text('No add-ons installed yet.', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Install a skill or plugin, then attach it here so every chat in this folder uses it.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.selected,
    required this.folders,
    this.indent = false,
    this.onOpenChat,
    this.onMoveChat,
    this.onRemoveChat,
  });

  final MindChatRecord chat;
  final bool selected;
  final bool indent;
  final List<MindChatFolder> folders;
  final ValueChanged<String>? onOpenChat;
  final void Function(String chatId, String? folderId)? onMoveChat;
  final ValueChanged<String>? onRemoveChat;

  @override
  Widget build(BuildContext context) {
    Widget tile() => ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: indent ? 12 : 0, right: 0),
      selected: selected,
      title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: chat.preview.isEmpty
          ? null
          : Text(chat.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onOpenChat == null ? null : () => onOpenChat!(chat.id),
      trailing: (onRemoveChat == null && onMoveChat == null)
          ? null
          : PopupMenuButton<String>(
              key: Key('mind.chats.row.menu.${chat.id}'),
              tooltip: 'Chat actions',
              onSelected: (value) {
                if (value == 'remove') {
                  unawaited(_confirmRemove(context));
                  return;
                }
                if (value == 'unfiled') {
                  onMoveChat?.call(chat.id, null);
                  return;
                }
                if (value.startsWith('move:')) {
                  onMoveChat?.call(chat.id, value.substring(5));
                }
              },
              itemBuilder: (context) => [
                if (onMoveChat != null) ...[
                  for (final folder in folders)
                    if (folder.id != chat.folderId)
                      PopupMenuItem(
                        value: 'move:${folder.id}',
                        child: Text('Move to ${folder.name}'),
                      ),
                  if (chat.folderId != null)
                    const PopupMenuItem(
                      value: 'unfiled',
                      child: Text('Remove from folder'),
                    ),
                ],
                if (onRemoveChat != null)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove chat'),
                  ),
              ],
            ),
    );

    final body = onMoveChat == null
        ? tile()
        : Draggable<String>(
            data: chat.id,
            maxSimultaneousDrags: 1,
            feedback: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(chat.title),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: tile()),
            child: tile(),
          );

    return KeyedSubtree(key: Key('mind.chats.row.${chat.id}'), child: body);
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this chat?'),
        content: const Text(
          'This deletes the transcript from this device. Folder knowledge stays.',
        ),
        actions: [
          TextButton(
            key: const Key('mind.chats.remove.cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('mind.chats.remove.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove == true) onRemoveChat?.call(chat.id);
  }
}
