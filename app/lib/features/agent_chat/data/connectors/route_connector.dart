import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';

class RouteConnector implements AgentConnector {
  @override
  String get name => 'open_route';

  @override
  Set<SkillCapability> get requiredCapabilities => {SkillCapability.routeOpen};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final rawTarget = _firstString(arguments, const [
      'route',
      'path',
      'feature',
      'target',
      'screen',
      'destination',
      'app',
    ]);
    if (rawTarget == null) {
      return const ConnectorResult.error(
        code: 'missing_route_target',
        message: 'Tell me which Airo feature to open.',
      );
    }

    final target = _resolveTarget(rawTarget);
    if (target == null) {
      return ConnectorResult.error(
        code: 'unknown_route_target',
        message: 'I do not know which Airo screen "$rawTarget" maps to yet.',
        data: {'target': rawTarget},
      );
    }

    return ConnectorResult(
      data: {
        'route': target.route,
        'parameters': target.parameters,
        'message': 'Opening ${target.label}.',
      },
    );
  }
}

class _RouteTarget {
  const _RouteTarget(this.route, this.label, [this.parameters = const {}]);

  final String route;
  final String label;
  final Map<String, dynamic> parameters;
}

String? _firstString(Map<String, dynamic> arguments, List<String> keys) {
  for (final key in keys) {
    final value = arguments[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

_RouteTarget? _resolveTarget(String rawTarget) {
  final normalized = _normalize(rawTarget);
  if (rawTarget.startsWith('/')) {
    return _knownPath(rawTarget);
  }

  return switch (normalized) {
    'money' || 'coins' || 'wallet' => const _RouteTarget('/money', 'Money'),
    'budget' || 'budgets' => const _RouteTarget('/money/budgets', 'Budgets'),
    'expenses' ||
    'expense' ||
    'add_expense' => const _RouteTarget('/money/add-expense', 'Add Expense'),
    'split' ||
    'split_bill' ||
    'bill_split' => const _RouteTarget('/money/split', 'Split Bill'),
    'assistant' ||
    'agent' ||
    'chat' => const _RouteTarget('/agent', 'Assistant'),
    'models' || 'model' || 'model_management' || 'offline_models' =>
      const _RouteTarget('/agent/profile', 'Profile model settings'),
    'music' || 'beats' => const _RouteTarget('/live/music', 'Music'),
    'tv' || 'stream' || 'streaming' => const _RouteTarget('/live/tv', 'TV'),
    'games' || 'arena' => const _RouteTarget('/games', 'Arena'),
    'chess' => const _RouteTarget('/games', 'Chess', {'game': 'chess'}),
    'quest' || 'tasks' => const _RouteTarget('/quest', 'Quest'),
    'image' ||
    'ask_image' ||
    'upload' => const _RouteTarget('/quest/new', 'Quest Upload'),
    'live_notes' ||
    'team_notes' ||
    'meeting_notes' ||
    'conversation_notes' ||
    'meetings' ||
    'meeting' => const _RouteTarget('/agent/live-notes', 'Live Notes'),
    _ => null,
  };
}

_RouteTarget? _knownPath(String path) {
  return switch (path) {
    '/money' => const _RouteTarget('/money', 'Money'),
    '/money/split' => const _RouteTarget('/money/split', 'Split Bill'),
    '/money/budgets' => const _RouteTarget('/money/budgets', 'Budgets'),
    '/money/add-expense' => const _RouteTarget(
      '/money/add-expense',
      'Add Expense',
    ),
    '/agent' => const _RouteTarget('/agent', 'Assistant'),
    '/agent/live-notes' => const _RouteTarget(
      '/agent/live-notes',
      'Live Notes',
    ),
    '/agent/meetings' => const _RouteTarget('/agent/live-notes', 'Live Notes'),
    '/agent/models' => const _RouteTarget('/agent/models', 'Project setup'),
    '/agent/profile' => const _RouteTarget(
      '/agent/profile',
      'Profile model settings',
    ),
    '/live/music' => const _RouteTarget('/live/music', 'Music'),
    '/live/tv' => const _RouteTarget('/live/tv', 'TV'),
    '/games' => const _RouteTarget('/games', 'Arena'),
    '/quest' => const _RouteTarget('/quest', 'Quest'),
    '/quest/new' => const _RouteTarget('/quest/new', 'Quest Upload'),
    '/meetings' => const _RouteTarget('/agent/live-notes', 'Live Notes'),
    _ => null,
  };
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
