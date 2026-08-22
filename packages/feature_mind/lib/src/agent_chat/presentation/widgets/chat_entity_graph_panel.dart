import 'package:flutter/material.dart';

import '../../domain/models/chat_entity_graph.dart';

/// Compact, on-device view of entities and relations extracted from chat.
///
/// Sizes to its content and caps the entity list against the window so a
/// Retina / large-text desktop never overflows the chat column.
class ChatEntityGraphPanel extends StatefulWidget {
  const ChatEntityGraphPanel({super.key, required this.graph});

  final ChatEntityGraph graph;

  @override
  State<ChatEntityGraphPanel> createState() => _ChatEntityGraphPanelState();
}

class _ChatEntityGraphPanelState extends State<ChatEntityGraphPanel> {
  var _expanded = true;

  @override
  Widget build(BuildContext context) {
    final graph = widget.graph;
    if (graph.nodes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(1);
    final maxListHeight = (media.size.height * 0.22 * scale).clamp(
      72.0,
      240.0,
    );

    return Material(
      key: const Key('chat.entity_graph.panel'),
      color: theme.colorScheme.surface.withValues(alpha: 0.72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked memory · ${graph.nodes.length} entities',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          '${graph.edges.length} relation${graph.edges.length == 1 ? '' : 's'} · stays on this device',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20 * scale.clamp(1, 1.4),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: graph.nodes.length,
                itemBuilder: (context, index) {
                  final node = graph.nodes[index];
                  final relations = graph
                      .edgesFor(node.id)
                      .map((edge) {
                        final otherId = edge.fromId == node.id
                            ? edge.toId
                            : edge.fromId;
                        final other = graph.nodeById(otherId);
                        if (other == null) return null;
                        final arrow = edge.fromId == node.id ? '→' : '←';
                        return '$arrow ${edge.predicate} ${other.name}';
                      })
                      .whereType<String>()
                      .join('\n');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${node.name} · ${node.type.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (relations.isNotEmpty)
                          Text(
                            relations,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
