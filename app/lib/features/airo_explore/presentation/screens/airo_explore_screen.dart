import 'package:flutter/material.dart';

import '../../../../core/exploration/airo_explorable_collection.dart';

class AiroExploreScreen extends StatelessWidget {
  const AiroExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AiroExplorableCollection<AiroExploreObject>(
          title: 'Airo Explore',
          subtitle:
              'Airo surfaces, automations, and local context in one browsable map',
          listLabel: 'Index View',
          spatialLabel: 'Map View',
          searchHint: 'Search Airo apps, models, skills, routines',
          randomLabel: 'Surprise',
          listHelpText:
              'Scan ownership, state, and entry points without leaving the shared filters.',
          spatialHelpText:
              'Browse adjacent Airo surfaces by workspace and open what catches your eye.',
          loadingLabel: 'Mapping Airo...',
          emptyTitle: 'Nothing in this Airo lane',
          emptyMessage: 'Clear search or pick another Airo category.',
          randomSeed: 7,
          items: airoExploreItems,
        ),
      ),
    );
  }
}

enum AiroExploreObjectKind { app, model, memory, skill, routine }

class AiroExploreObject {
  const AiroExploreObject({
    required this.kind,
    required this.owner,
    required this.priority,
  });

  final AiroExploreObjectKind kind;
  final String owner;
  final String priority;
}

const airoExploreItems = [
  AiroExplorableCollectionItem<AiroExploreObject>(
    id: 'mind-inbox',
    title: 'Mind Inbox',
    subtitle: 'Conversation-first entry into Airo',
    category: 'Workspace',
    group: 'Airo Home',
    details:
        'The practical list entry stays tied to the same object that appears in spatial discovery.',
    tags: ['Chat', 'Local context', 'Drafts'],
    metrics: {'Owner': 'Brain Agent', 'Mode': 'Interactive'},
    icon: Icons.psychology_outlined,
    color: Color(0xFF1565C0),
    semanticLabel: 'Mind Inbox, conversation-first entry into Airo',
    payload: AiroExploreObject(
      kind: AiroExploreObjectKind.app,
      owner: 'Brain Agent',
      priority: 'High',
    ),
  ),
  AiroExplorableCollectionItem<AiroExploreObject>(
    id: 'model-library',
    title: 'Model Library',
    subtitle: 'Local and selected assistant runtimes',
    category: 'AI',
    group: 'Airo Home',
    details:
        'Keeps runtime choice inspectable beside the experiences that depend on it.',
    tags: ['Gemini Nano', 'LiteRT', 'Preferences'],
    metrics: {'Routing': 'Local-first', 'Fallback': 'Visible'},
    icon: Icons.memory_outlined,
    color: Color(0xFF2E7D32),
    payload: AiroExploreObject(
      kind: AiroExploreObjectKind.model,
      owner: 'Framework Agent',
      priority: 'High',
    ),
  ),
  AiroExplorableCollectionItem<AiroExploreObject>(
    id: 'memory-vault',
    title: 'Memory Vault',
    subtitle: 'Local user context and recall',
    category: 'AI',
    group: 'Context Layer',
    details:
        'Airo-owned memory belongs beside permissions, retention, and retrieval controls.',
    tags: ['Local-first', 'Recall', 'Retention'],
    metrics: {'Storage': 'Local', 'Privacy': 'Required'},
    icon: Icons.folder_special_outlined,
    color: Color(0xFF6A1B9A),
    payload: AiroExploreObject(
      kind: AiroExploreObjectKind.memory,
      owner: 'Memory Agent',
      priority: 'High',
    ),
  ),
  AiroExplorableCollectionItem<AiroExploreObject>(
    id: 'skill-lab',
    title: 'Skill Lab',
    subtitle: 'Discoverable Airo skills and connectors',
    category: 'Skills',
    group: 'Context Layer',
    details:
        'The same skill can be found through search, filters, or nearby related capabilities.',
    tags: ['Skills', 'Connectors', 'Trust'],
    metrics: {'Sandbox': 'Planned', 'Review': 'Required'},
    icon: Icons.extension_outlined,
    color: Color(0xFF00838F),
    payload: AiroExploreObject(
      kind: AiroExploreObjectKind.skill,
      owner: 'Agent Skills Agent',
      priority: 'High',
    ),
  ),
  AiroExplorableCollectionItem<AiroExploreObject>(
    id: 'routine-packs',
    title: 'Routine Packs',
    subtitle: 'Repeatable workflows for Airo OS',
    category: 'Automations',
    group: 'Automation Layer',
    details:
        'Routine discovery supports both deliberate lookup and serendipitous browsing.',
    tags: ['Templates', 'Schedules', 'Checklists'],
    metrics: {'State': 'Draftable', 'Trigger': 'User-owned'},
    icon: Icons.task_alt_outlined,
    color: Color(0xFFEF6C00),
    payload: AiroExploreObject(
      kind: AiroExploreObjectKind.routine,
      owner: 'Routine OS Agent',
      priority: 'High',
    ),
  ),
  AiroExplorableCollectionItem<AiroExploreObject>(
    id: 'scheduled-actions',
    title: 'Scheduled Actions',
    subtitle: 'Notifications and time-based automation',
    category: 'Automations',
    group: 'Automation Layer',
    details:
        'Spatial adjacency makes it clear which routines rely on timers, permissions, and failure handling.',
    tags: ['Notifications', 'Timers', 'Failure paths'],
    metrics: {'Permission': 'Explicit', 'Trace': 'Required'},
    icon: Icons.schedule_outlined,
    color: Color(0xFFC62828),
    payload: AiroExploreObject(
      kind: AiroExploreObjectKind.routine,
      owner: 'Framework Agent',
      priority: 'Medium',
    ),
  ),
  AiroExplorableCollectionItem<AiroExploreObject>(
    id: 'coins-dashboard',
    title: 'Coins Dashboard',
    subtitle: 'Airo money view with budgets and groups',
    category: 'Apps',
    group: 'Airo Apps',
    details:
        'Domain apps can reuse the component while keeping finance data and privacy rules app-owned.',
    tags: ['Budgets', 'Groups', 'Safe to spend'],
    metrics: {'Domain': 'Finance', 'Privacy': 'Sensitive'},
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF455A64),
    payload: AiroExploreObject(
      kind: AiroExploreObjectKind.app,
      owner: 'Coins Agent',
      priority: 'High',
    ),
  ),
  AiroExplorableCollectionItem<AiroExploreObject>(
    id: 'media-hub',
    title: 'Media Hub',
    subtitle: 'Music, stream, and discovery surfaces',
    category: 'Apps',
    group: 'Airo Apps',
    details:
        'Airo can expose catalog-style media browsing through the same shared interaction model.',
    tags: ['Music', 'Stream', 'Discovery'],
    metrics: {'Mode': 'Browse', 'Controls': 'Media'},
    icon: Icons.play_circle_outline,
    color: Color(0xFF5D4037),
    payload: AiroExploreObject(
      kind: AiroExploreObjectKind.app,
      owner: 'Media Agent',
      priority: 'Medium',
    ),
  ),
  AiroExplorableCollectionItem<AiroExploreObject>(
    id: 'quest-board',
    title: 'Quest Board',
    subtitle: 'Goal and task exploration surface',
    category: 'Workspace',
    group: 'Airo Apps',
    details:
        'Quest items can later move between dense task lists and visual relationship maps.',
    tags: ['Goals', 'Tasks', 'Progress'],
    metrics: {'State': 'Explorable', 'Fallback': 'List'},
    icon: Icons.workspace_premium_outlined,
    color: Color(0xFF7B1FA2),
    payload: AiroExploreObject(
      kind: AiroExploreObjectKind.app,
      owner: 'Application Agent',
      priority: 'Medium',
    ),
  ),
];
