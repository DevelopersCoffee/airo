import 'package:equatable/equatable.dart';
import 'intent_parser.dart';

/// Gallery-style card describing an agent skill/use case.
class AgentSkillCard extends Equatable {
  final String key;
  final String title;
  final String description;
  final String iconKey;
  final String? route;
  final bool featured;

  const AgentSkillCard({
    required this.key,
    required this.title,
    required this.description,
    required this.iconKey,
    this.route,
    this.featured = false,
  });

  @override
  List<Object?> get props => [
    key,
    title,
    description,
    iconKey,
    route,
    featured,
  ];
}

/// Result returned by an Airo agent tool.
class AgentToolResult extends Equatable {
  final String message;
  final String? route;
  final Map<String, dynamic> parameters;
  final bool isError;

  const AgentToolResult({
    required this.message,
    this.route,
    this.parameters = const {},
    this.isError = false,
  });

  bool get shouldNavigate => route != null && route != '/agent';

  NavTarget? toNavTarget() {
    if (route == null) return null;
    return NavTarget(route: route!, parameters: parameters, message: message);
  }

  @override
  List<Object?> get props => [message, route, parameters, isError];
}

/// Navigation target returned by tool.
class NavTarget extends Equatable {
  final String route;
  final Map<String, dynamic> parameters;
  final String? message;

  const NavTarget({
    required this.route,
    this.parameters = const {},
    this.message,
  });

  @override
  List<Object?> get props => [route, parameters, message];
}

/// Tool interface for handling intents.
abstract class Tool {
  String get key;
  String get name;

  Future<AgentToolResult?> handle(Intent intent);

  bool canHandle(Intent intent);
}

/// Music tool.
class MusicTool implements Tool {
  @override
  String get key => 'Beats';

  @override
  String get name => 'Beats';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.playMusic ||
        intent.type == IntentType.pauseMusic ||
        intent.type == IntentType.nextTrack;
  }

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    switch (intent.type) {
      case IntentType.playMusic:
        return const AgentToolResult(
          route: '/live/music',
          message: 'Now playing music',
        );
      case IntentType.pauseMusic:
        return const AgentToolResult(
          route: '/live/music',
          message: 'Music paused',
        );
      case IntentType.nextTrack:
        return const AgentToolResult(
          route: '/live/music',
          message: 'Skipping to next track',
        );
      default:
        return null;
    }
  }
}

/// Money and model-management routing tool.
class MoneyTool implements Tool {
  @override
  String get key => 'Coins';

  @override
  String get name => 'Coins';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.openMoney ||
        intent.type == IntentType.openBudget ||
        intent.type == IntentType.openExpenses ||
        intent.type == IntentType.modelManagement;
  }

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    switch (intent.type) {
      case IntentType.openMoney:
        return const AgentToolResult(
          route: '/money',
          message: 'Opening Money app',
        );
      case IntentType.openBudget:
        return const AgentToolResult(
          route: '/money',
          parameters: {'tab': 'budget'},
          message: 'Opening Budget',
        );
      case IntentType.openExpenses:
        return const AgentToolResult(
          route: '/money',
          parameters: {'tab': 'expenses'},
          message: 'Opening Expenses',
        );
      case IntentType.modelManagement:
        return const AgentToolResult(
          route: '/agent/profile',
          message: 'Opening Profile model settings.',
        );
      default:
        return null;
    }
  }
}

/// Split bill tool that can answer directly in chat.
class SplitBillTool implements Tool {
  @override
  String get key => 'split_bill';

  @override
  String get name => 'Split Bill';

  @override
  bool canHandle(Intent intent) => intent.type == IntentType.splitBill;

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    final amountCents = intent.parameters['amountCents'] as int?;
    final participants =
        (intent.parameters['participants'] as List?)?.cast<String>() ??
        const [];
    final currencyCode = intent.parameters['currencyCode'] as String? ?? 'INR';

    if (amountCents == null || participants.isEmpty) {
      return const AgentToolResult(
        route: '/money/split',
        message: 'Opening Split Bill. Add the amount and participants there.',
      );
    }

    final baseShare = amountCents ~/ participants.length;
    var remainder = amountCents % participants.length;
    final lines = <String>[];

    for (final participant in participants) {
      final extra = remainder > 0 ? 1 : 0;
      if (remainder > 0) remainder--;
      lines.add(
        '- $participant: ${_formatMoney(baseShare + extra, currencyCode)}',
      );
    }

    return AgentToolResult(
      message:
          'Split Bill\n'
          'Total: ${_formatMoney(amountCents, currencyCode)}\n'
          'Participants: ${participants.length}\n'
          '${lines.join('\n')}\n\n'
          'Open Split Bill if you want to save this with a receipt or custom payer.',
    );
  }
}

/// Diet planner tool for a practical first-pass draft.
class DietPlanTool implements Tool {
  @override
  String get key => 'diet_plan';

  @override
  String get name => 'Diet Plan';

  @override
  bool canHandle(Intent intent) => intent.type == IntentType.createDietPlan;

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    return const AgentToolResult(
      message:
          '7-day diet plan draft\n'
          'Day 1: oats, dal bowl, curd, fruit\n'
          'Day 2: poha, paneer wrap, sprouts, vegetable khichdi\n'
          'Day 3: eggs or tofu, rice bowl, nuts, soup\n'
          'Day 4: idli, chana salad, buttermilk, roti sabzi\n'
          'Day 5: smoothie, rajma rice, fruit, stir-fry\n'
          'Day 6: upma, quinoa bowl, yogurt, dal roti\n'
          'Day 7: dosa, grilled protein, salad, light dinner\n\n'
          'I can refine this by calories, cuisine, allergies, budget, or workout goal.',
    );
  }
}

/// Routine planner tool for daily planning from chat.
class RoutineTool implements Tool {
  @override
  String get key => 'routine_planner';

  @override
  String get name => 'Routine Planner';

  @override
  bool canHandle(Intent intent) => intent.type == IntentType.createRoutine;

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    return const AgentToolResult(
      message:
          'Daily routine draft\n'
          'Morning: plan top 3 tasks, deep work block, quick review\n'
          'Afternoon: admin, errands, light study or practice\n'
          'Evening: exercise, dinner, reset workspace\n'
          'Night: review progress, prepare tomorrow, wind down\n\n'
          'Tell me your wake time, sleep time, and main goal to make this precise.',
    );
  }
}

/// Games tool. This deliberately maps Gallery's game pattern to Airo Arena.
class GamesTool implements Tool {
  @override
  String get key => 'Arena';

  @override
  String get name => 'Arena';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.playGames ||
        intent.type == IntentType.playChess ||
        intent.type == IntentType.playGame;
  }

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    switch (intent.type) {
      case IntentType.playGames:
        return const AgentToolResult(route: '/games', message: 'Opening Arena');
      case IntentType.playChess:
        return const AgentToolResult(
          route: '/games',
          parameters: {'game': 'chess'},
          message: 'Opening Chess in Arena',
        );
      case IntentType.playGame:
        final game = intent.parameters['game'] as String? ?? 'games';
        return AgentToolResult(
          route: '/games',
          parameters: {'game': game},
          message: 'Opening ${_titleCase(game)} in Arena',
        );
      default:
        return null;
    }
  }
}

/// Offers tool.
class OffersTool implements Tool {
  @override
  String get key => 'Loot';

  @override
  String get name => 'Loot';

  @override
  bool canHandle(Intent intent) => intent.type == IntentType.openOffers;

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    return const AgentToolResult(route: '/offers', message: 'Opening Offers');
  }
}

/// Reader tool.
class ReaderTool implements Tool {
  @override
  String get key => 'Tales';

  @override
  String get name => 'Tales';

  @override
  bool canHandle(Intent intent) => intent.type == IntentType.openReader;

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    return const AgentToolResult(route: '/reader', message: 'Opening Reader');
  }
}

/// Social/Chat tool.
class SocialTool implements Tool {
  @override
  String get key => 'social';

  @override
  String get name => 'Social';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.openChat ||
        intent.type == IntentType.askImage ||
        intent.type == IntentType.audioScribe ||
        intent.type == IntentType.mobileActions;
  }

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    switch (intent.type) {
      case IntentType.askImage:
        return const AgentToolResult(
          route: '/quest/new',
          message: 'Opening Quest upload for image or document analysis.',
        );
      case IntentType.audioScribe:
        return const AgentToolResult(
          message:
              'Audio Scribe is mapped to Airo voice workflows. Use voice input now; full offline transcription can plug into the meeting-minutes pipeline.',
        );
      case IntentType.mobileActions:
        return const AgentToolResult(
          message:
              'Mobile Actions ready: try commands like "open WiFi settings", "show budget", "play chess", or "split this bill". Sensitive device actions should ask for confirmation before execution.',
        );
      case IntentType.openChat:
        return const AgentToolResult(route: '/agent', message: 'Opening Chat');
      default:
        return null;
    }
  }
}

/// Tool registry - manages all available tools.
class ToolRegistry {
  static final ToolRegistry _instance = ToolRegistry._internal();

  final Map<String, Tool> _tools = {
    'split_bill': SplitBillTool(),
    'diet_plan': DietPlanTool(),
    'routine_planner': RoutineTool(),
    'Beats': MusicTool(),
    'Coins': MoneyTool(),
    'Arena': GamesTool(),
    'Loot': OffersTool(),
    'Tales': ReaderTool(),
    'social': SocialTool(),
  };

  ToolRegistry._internal();

  factory ToolRegistry() {
    return _instance;
  }

  /// Get tool by key.
  Tool? getTool(String key) => _tools[key];

  /// Get all tools.
  List<Tool> getAllTools() => _tools.values.toList();

  /// Get Gallery-style feature cards for the chat prompt surface.
  List<AgentSkillCard> getSkillCards() {
    return const [
      AgentSkillCard(
        key: 'ai_chat',
        title: 'AI Chat',
        description: 'Chat with on-device AI when available',
        iconKey: 'chat',
        route: '/agent',
        featured: true,
      ),
      AgentSkillCard(
        key: 'agent_skills',
        title: 'Agent Skills',
        description: 'Use tools for routine tasks',
        iconKey: 'send',
        featured: true,
      ),
      AgentSkillCard(
        key: 'calendar_today',
        title: 'Calendar',
        description: 'Check today\'s schedule with a skill',
        iconKey: 'calendar',
        featured: true,
      ),
      AgentSkillCard(
        key: 'smart_reminders',
        title: 'Smart Reminders',
        description: 'Schedule medicine, family, and habit reminders',
        iconKey: 'notifications',
        featured: true,
      ),
      AgentSkillCard(
        key: 'split_bill',
        title: 'Split Bill',
        description: 'Calculate shares or open bill split',
        iconKey: 'receipt',
        route: '/money/split',
      ),
      AgentSkillCard(
        key: 'diet_plan',
        title: 'Diet Plan',
        description: 'Draft a practical meal plan',
        iconKey: 'restaurant',
      ),
      AgentSkillCard(
        key: 'routine_planner',
        title: 'Routine',
        description: 'Plan study, work, and daily tasks',
        iconKey: 'task',
      ),
      AgentSkillCard(
        key: 'ask_image',
        title: 'Ask Image',
        description: 'Analyze images via Quest upload',
        iconKey: 'image',
        route: '/quest/new',
      ),
      AgentSkillCard(
        key: 'audio_scribe',
        title: 'Audio Scribe',
        description: 'Prepare offline transcription workflows',
        iconKey: 'mic',
      ),
      AgentSkillCard(
        key: 'mobile_actions',
        title: 'Mobile Actions',
        description: 'Control Airo features with commands',
        iconKey: 'bolt',
      ),
      AgentSkillCard(
        key: 'model_management',
        title: 'Model Management',
        description: 'Manage offline AI models',
        iconKey: 'model',
        route: '/agent/models',
      ),
      AgentSkillCard(
        key: 'arena_games',
        title: 'Arena Games',
        description: 'Play Airo games from chat',
        iconKey: 'sports_esports',
        route: '/games',
      ),
    ];
  }

  /// Find tool that can handle intent.
  Tool? findToolForIntent(Intent intent) {
    for (final tool in _tools.values) {
      if (tool.canHandle(intent)) {
        return tool;
      }
    }
    return null;
  }

  /// Handle intent with appropriate tool.
  Future<AgentToolResult> executeIntent(Intent intent) async {
    final tool = findToolForIntent(intent);
    if (tool == null) {
      return const AgentToolResult(
        message: 'Sorry, that command is not supported yet.',
        isError: true,
      );
    }
    return await tool.handle(intent) ??
        const AgentToolResult(
          message: 'Sorry, that command is not supported yet.',
          isError: true,
        );
  }

  /// Compatibility method for older call sites.
  Future<NavTarget?> handleIntent(Intent intent) async {
    return (await executeIntent(intent)).toNavTarget();
  }
}

String _formatMoney(int amountCents, String currencyCode) {
  final amount = (amountCents / 100).toStringAsFixed(2);
  if (currencyCode == 'USD') return '\$$amount';
  return '₹$amount';
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
