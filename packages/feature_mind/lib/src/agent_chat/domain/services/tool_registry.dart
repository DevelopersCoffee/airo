import 'package:equatable/equatable.dart';
import 'package:core_ai/core_ai.dart';

import '../../../assistant/assistant_surface_policy.dart';
import '../../../meeting_archive/meeting_archive_port.dart';
import '../../../services/device_actions_service.dart';
import '../../../routing/assistant_route_names.dart';
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

/// Safe platform actions exposed through the Mobile Actions skill.
class DeviceActionsTool implements Tool {
  DeviceActionsTool({DeviceActionsService? service})
    : _service = service ?? DeviceActionsService();

  final DeviceActionsService _service;

  @override
  String get key => 'mobile_actions';

  @override
  String get name => 'Mobile Actions';

  @override
  bool canHandle(Intent intent) => {
    IntentType.openWifiSettings,
    IntentType.setFlashlight,
    IntentType.composeEmail,
    IntentType.createContact,
    IntentType.openMap,
  }.contains(intent.type);

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    if (!canHandle(intent)) return null;
    final opened = switch (intent.type) {
      IntentType.openWifiSettings => await _service.openWifiSettings(),
      IntentType.setFlashlight => await _service.setFlashlight(
        enabled: intent.parameters['enabled'] != false,
      ),
      IntentType.composeEmail => await _service.composeEmail(),
      IntentType.createContact => await _service.createContact(),
      IntentType.openMap => await _service.openMap(),
      _ => false,
    };
    return AgentToolResult(
      message: opened ? _successMessage(intent) : _failureMessage(intent),
      isError: !opened,
    );
  }

  String _successMessage(Intent intent) => switch (intent.type) {
    IntentType.openWifiSettings => 'Opened Wi-Fi settings.',
    IntentType.setFlashlight =>
      intent.parameters['enabled'] == false
          ? 'Turned the flashlight off.'
          : 'Turned the flashlight on.',
    IntentType.composeEmail => 'Opened the email composer.',
    IntentType.createContact => 'Opened the contact form.',
    IntentType.openMap => 'Opened the map.',
    _ => 'Completed the device action.',
  };

  String _failureMessage(Intent intent) => switch (intent.type) {
    IntentType.openWifiSettings =>
      'Airo could not open Wi-Fi settings on this device.',
    IntentType.setFlashlight => 'Airo could not change the flashlight.',
    IntentType.composeEmail => 'Airo could not open an email composer.',
    IntentType.createContact => 'Airo could not open the contact form.',
    IntentType.openMap => 'Airo could not open a map on this device.',
    _ => 'Airo could not complete the device action.',
  };
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
          route: '/agent/models',
          message: 'Opening model manager.',
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

/// Retired: meal plans are written by the chat model via the Diet Plan plugin.
class DietPlanTool implements Tool {
  @override
  String get key => 'diet_plan';

  @override
  String get name => 'Diet Plan';

  @override
  bool canHandle(Intent intent) => false;

  @override
  Future<AgentToolResult?> handle(Intent intent) async => null;
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

/// Queries the offline meeting archive via [MeetingArchivePort] (#1770).
class MeetingArchiveTool implements Tool {
  MeetingArchiveTool(this._port);

  final MeetingArchivePort? _port;

  @override
  String get key => 'meeting_archive';

  @override
  String get name => 'Meeting Archive';

  @override
  bool canHandle(Intent intent) {
    return intent.type == IntentType.searchMeetings ||
        intent.type == IntentType.openMeetingScribe ||
        intent.type == IntentType.getMeetingMom ||
        intent.type == IntentType.myActionItems;
  }

  @override
  Future<AgentToolResult?> handle(Intent intent) async {
    final port = _port;
    if (port == null) {
      return const AgentToolResult(
        route: '/scribe',
        message:
            'Meeting Scribe is not available in this shell. Open the Mind tab on phone.',
      );
    }

    switch (intent.type) {
      case IntentType.openMeetingScribe:
        return const AgentToolResult(
          route: '/scribe',
          message: 'Opening Meeting Scribe.',
        );
      case IntentType.searchMeetings:
        final query = (intent.parameters['query'] as String?)?.trim() ?? '';
        if (query.isEmpty) {
          return const AgentToolResult(
            route: '/scribe',
            message: 'Opening Meeting Scribe to search your archive.',
          );
        }
        final ranked = await port.searchAligned(query);
        if (ranked.hits.isEmpty) {
          return AgentToolResult(
            message: 'No meetings matched "$query" in your local archive.',
          );
        }
        final lines = ranked.hits
            .take(5)
            .map((hit) => '• ${hit.title}: ${hit.snippet}')
            .join('\n');
        final caveat = ranked.hasEmbeddingMismatch
            ? '\n\n${RetrievalAlignment.userNote}'
            : '';
        return AgentToolResult(
          message:
              'Found ${ranked.hits.length} meeting(s) for "$query":\n$lines$caveat',
        );
      case IntentType.getMeetingMom:
        final query = (intent.parameters['query'] as String?)?.trim() ?? '';
        if (query.isNotEmpty) {
          final hits = (await port.searchAligned(query)).hits;
          if (hits.isEmpty) {
            return AgentToolResult(
              message:
                  'No saved meeting matched "$query". Record or process a meeting in Scribe first.',
            );
          }
          final minutes = await port.minutesForMeeting(hits.first.meetingId);
          if (minutes == null) {
            return AgentToolResult(
              message:
                  'Found "${hits.first.title}" but minutes are not ready yet. Open Meeting Scribe to finish processing.',
              route: '/scribe',
            );
          }
          return AgentToolResult(message: minutes);
        }
        final latest = await port.latestWithMinutes();
        if (latest == null) {
          return const AgentToolResult(
            route: '/scribe',
            message:
                'No minutes found yet. Record a meeting in Scribe and wait for processing to finish.',
          );
        }
        return AgentToolResult(message: latest.minutes);
      case IntentType.myActionItems:
        final owner = (intent.parameters['owner'] as String?)?.trim() ?? 'me';
        final items = await port.actionItemsForOwner(owner);
        if (items.isEmpty) {
          return AgentToolResult(
            message: owner == 'me'
                ? 'No open action items assigned to you in saved meetings.'
                : 'No action items found for $owner.',
          );
        }
        final lines = items
            .take(8)
            .map(
              (item) =>
                  '• ${item.task}${item.due == null ? '' : ' (due ${item.due})'}',
            )
            .join('\n');
        return AgentToolResult(message: 'Action items:\n$lines');
      default:
        return null;
    }
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
          route: '/assistant/audio-scribe',
          message:
              'Opening Audio Scribe for on-device capture, transcript review, and translation.',
        );
      case IntentType.mobileActions:
        return const AgentToolResult(
          message:
              'Mobile Actions ready: try "open WiFi settings", "turn the flashlight on", "create contact", "send email", or "show location on map". Sensitive device actions should ask for confirmation before execution.',
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

  MeetingArchivePort? _meetingArchive;

  final Map<String, Tool> _tools = {
    'split_bill': SplitBillTool(),
    'diet_plan': DietPlanTool(),
    'routine_planner': RoutineTool(),
    'Beats': MusicTool(),
    'Coins': MoneyTool(),
    'Arena': GamesTool(),
    'Loot': OffersTool(),
    'Tales': ReaderTool(),
    'mobile_actions': DeviceActionsTool(),
    'social': SocialTool(),
  };

  ToolRegistry._internal() {
    _tools['meeting_archive'] = MeetingArchiveTool(_meetingArchive);
  }

  /// Wires the offline meeting archive for chat tools (#1770). Called from
  /// [MindModule.initialize] when the scribe is mounted.
  void configureMeetingArchive(MeetingArchivePort? port) {
    _meetingArchive = port;
    _tools['meeting_archive'] = MeetingArchiveTool(port);
  }

  factory ToolRegistry() {
    return _instance;
  }

  /// Get tool by key.
  Tool? getTool(String key) => _tools[key];

  /// Get all tools.
  List<Tool> getAllTools() => _tools.values.toList();

  /// Get Gallery-style feature cards for the chat prompt surface.
  List<AgentSkillCard> getSkillCards({
    AssistantSurfacePolicy policy = AssistantSurfacePolicy.mobile,
  }) {
    return _allSkillCards().where((card) {
      return switch (card.key) {
        'ask_image' => policy.showQuestImage,
        'mobile_actions' || 'tiny_garden' => policy.showMobileActions,
        'arena_games' => policy.showArenaGames,
        _ => true,
      };
    }).toList();
  }

  List<AgentSkillCard> _allSkillCards() {
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
        key: 'add_ons',
        title: 'Add-ons',
        description: 'Install skills and plugins for folders',
        iconKey: 'extension',
        route: AssistantRouteNames.agentSkills,
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
        route: '/assistant/audio-scribe',
      ),
      AgentSkillCard(
        key: 'mobile_actions',
        title: 'Mobile Actions',
        description: 'Control Airo features with commands',
        iconKey: 'bolt',
        route: '/assistant/mobile-actions',
      ),
      AgentSkillCard(
        key: 'tiny_garden',
        title: 'Tiny Garden',
        description: 'Play the local language garden experiment',
        iconKey: 'local_florist',
        route: '/assistant/mobile-actions',
      ),
      AgentSkillCard(
        key: 'model_management',
        title: 'Intelligence',
        description: 'Pick a job. Airo selects the models.',
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
