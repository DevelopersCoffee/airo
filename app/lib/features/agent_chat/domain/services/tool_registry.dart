import 'package:equatable/equatable.dart';
import 'intent_parser.dart';

/// Navigation target returned by tool
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

/// Tool interface for handling intents
abstract class Tool {
  String get key;
  String get name;

  /// Handle intent and return navigation target
  Future<NavTarget?> handle(Intent intent);

  /// Check if this tool can handle the intent
  bool canHandle(Intent intent);
}

/// Music tool
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
  Future<NavTarget?> handle(Intent intent) async {
    switch (intent.type) {
      case IntentType.playMusic:
        return NavTarget(route: '/music', message: 'Now playing music');
      case IntentType.pauseMusic:
        return NavTarget(route: '/music', message: 'Music paused');
      case IntentType.nextTrack:
        return NavTarget(route: '/music', message: 'Skipping to next track');
      default:
        return null;
    }
  }
}

/// Money tool
class MoneyTool implements Tool {
  @override
  String get key => 'Coins';

  @override
  String get name => 'Coins';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.openMoney ||
        intent.type == IntentType.openBudget ||
        intent.type == IntentType.openExpenses;
  }

  @override
  Future<NavTarget?> handle(Intent intent) async {
    switch (intent.type) {
      case IntentType.openMoney:
        return NavTarget(route: '/money', message: 'Opening Money app');
      case IntentType.openBudget:
        return NavTarget(
          route: '/money',
          parameters: {'tab': 'budget'},
          message: 'Opening Budget',
        );
      case IntentType.openExpenses:
        return NavTarget(
          route: '/money',
          parameters: {'tab': 'expenses'},
          message: 'Opening Expenses',
        );
      default:
        return null;
    }
  }
}

/// Games tool
class GamesTool implements Tool {
  @override
  String get key => 'Arena';

  @override
  String get name => 'Arena';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.playGames ||
        intent.type == IntentType.playChess;
  }

  @override
  Future<NavTarget?> handle(Intent intent) async {
    switch (intent.type) {
      case IntentType.playGames:
        return NavTarget(route: '/games', message: 'Opening Games');
      case IntentType.playChess:
        return NavTarget(
          route: '/games',
          parameters: {'game': 'chess'},
          message: 'Opening Chess',
        );
      default:
        return null;
    }
  }
}

/// Offers tool
class OffersTool implements Tool {
  @override
  String get key => 'Loot';

  @override
  String get name => 'Loot';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.openOffers;
  }

  @override
  Future<NavTarget?> handle(Intent intent) async {
    return NavTarget(route: '/offers', message: 'Opening Offers');
  }
}

/// Reader tool
class ReaderTool implements Tool {
  @override
  String get key => 'Tales';

  @override
  String get name => 'Tales';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.openReader;
  }

  @override
  Future<NavTarget?> handle(Intent intent) async {
    return NavTarget(route: '/reader', message: 'Opening Reader');
  }
}

/// Social/Chat tool
class SocialTool implements Tool {
  @override
  String get key => 'social';

  @override
  String get name => 'Social';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.openChat;
  }

  @override
  Future<NavTarget?> handle(Intent intent) async {
    return NavTarget(route: '/agent', message: 'Opening Chat');
  }
}

/// Tool registry - manages all available tools
class ToolRegistry {
  static final ToolRegistry _instance = ToolRegistry._internal();

  final Map<String, Tool> _tools = {
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

  /// Get tool by key
  Tool? getTool(String key) => _tools[key];

  /// Get all tools
  List<Tool> getAllTools() => _tools.values.toList();

  /// Find tool that can handle intent
  Tool? findToolForIntent(Intent intent) {
    for (final tool in _tools.values) {
      if (tool.canHandle(intent)) {
        return tool;
      }
    }
    return null;
  }

  /// Handle intent with appropriate tool
  Future<NavTarget?> handleIntent(Intent intent) async {
    final tool = findToolForIntent(intent);
    if (tool == null) {
      return NavTarget(
        route: '/agent',
        message: 'Sorry, that command is not supported yet.',
      );
    }
    return tool.handle(intent);
  }
}
