import 'package:core_ai/core_ai.dart' show ModelCatalog;
import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import 'agent_chat/presentation/screens/agent_skills_screen.dart';
import 'agent_chat/presentation/screens/chat_screen.dart';
import 'agent_chat/presentation/screens/device_capability_report_screen.dart';
import 'agent_chat/presentation/screens/model_advisor_screen.dart';
import 'agent_chat/presentation/screens/model_library_screen.dart';
import 'agent_chat/presentation/screens/notifications_screen.dart';
import 'agent_chat/presentation/screens/profile_screen.dart';
import 'assistant/presentation/screens/assistant_screen.dart';
import 'assistant/presentation/screens/audio_scribe_screen.dart';
import 'assistant/presentation/screens/mobile_actions_screen.dart';
import 'assistant/presentation/screens/prompt_lab_screen.dart';
import 'host/assistant_host_adapter.dart';
import 'routing/assistant_route_names.dart';
import 'wellbeing/presentation/screens/wellbeing_screen.dart';

/// Builds the host adapter for a shell, given that shell's Riverpod [Ref].
///
/// A factory rather than a ready-made instance: a host adapter is normally a
/// thin wrapper over the shell's own providers (settings, auth, finance), so
/// it needs the `Ref` that only exists once the `ProviderContainer` is being
/// built. Shells pass a constructor tear-off, e.g.
/// `AssistantModule(hostAdapterBuilder: AppAssistantHostAdapter.new)`.
typedef AssistantHostAdapterBuilder = AssistantHostAdapter Function(Ref ref);

/// The Airo Mind tab, as a shell-agnostic module.
///
/// Owns both halves of the assistant's navigation surface:
///
/// * [hubRoutesFor] — the assistant hub and its children, which a shell mounts
///   inside whatever navigation branch shows the Mind tab.
/// * [rootRoutesFor] — destinations that are reached *from* the hub but are not
///   part of it, currently only Wellbeing. These must sit at the shell's top
///   level: Wellbeing is a full-screen destination, and mounting it inside the
///   Mind branch would wrap it in the super app's bottom navigation.
///
/// [routesFor] returns both, hub-first, so [ModuleRegistry] still sees the
/// module's complete path/name surface for conflict detection. Shells that
/// need the distinction call the two accessors instead of splitting the
/// combined list by path.
class AssistantModule extends AppModule {
  AssistantModule({
    required this.hostAdapterBuilder,
    this.basePath = AssistantRouteNames.assistant,
  }) : assert(basePath.startsWith('/'), 'basePath must be absolute');

  /// Builds the shell's implementation of the assistant's host seam.
  final AssistantHostAdapterBuilder hostAdapterBuilder;

  /// Absolute path the assistant hub mounts at. Both shipping shells use
  /// `/assistant` so deep links and notification payloads stay identical.
  final String basePath;

  @override
  String get id => 'assistant';

  /// Phone-class shells only, matching `module.yaml` (`tv: Never Ship`).
  @override
  Set<ShellId> get supportedShells => {ShellId.mobile, ShellId.mind};

  /// The module owns installing its own host seam, so a shell can never mount
  /// the assistant's routes while forgetting the adapter they depend on.
  @override
  List<Override> providerOverridesFor(ShellId shell) => [
    assistantHostAdapterProvider.overrideWith(hostAdapterBuilder),
  ];

  @override
  List<RouteBase> routesFor(ShellId shell) => [
    ...hubRoutesFor(shell),
    ...rootRoutesFor(shell),
  ];

  /// The assistant hub and everything nested under it.
  List<RouteBase> hubRoutesFor(ShellId shell) => [
    GoRoute(
      path: basePath,
      name: AssistantRouteNames.assistantName,
      builder: (context, state) => const AssistantScreen(),
      routes: [
        GoRoute(
          path: AssistantRouteNames.chatSegment,
          name: AssistantRouteNames.chatName,
          builder: (context, state) =>
              ChatScreen(initialDraft: state.uri.queryParameters['prefill']),
        ),
        GoRoute(
          path: AssistantRouteNames.notificationsSegment,
          name: AssistantRouteNames.notificationsName,
          builder: (context, state) => NotificationsScreen(
            initialCategory: state.uri.queryParameters['category'],
          ),
        ),
        GoRoute(
          path: AssistantRouteNames.profileSegment,
          name: AssistantRouteNames.profileName,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AssistantRouteNames.modelsSegment,
          name: AssistantRouteNames.modelsName,
          builder: (context, state) => ModelLibraryScreen(
            onModelSelected: (candidate) => context.go(basePath),
            onOpenModelManager: () =>
                context.push('$basePath/${AssistantRouteNames.profileSegment}'),
          ),
        ),
        GoRoute(
          path: AssistantRouteNames.deviceCapabilitiesSegment,
          name: AssistantRouteNames.deviceCapabilitiesName,
          builder: (context, state) => DeviceCapabilityReportLoaderScreen(
            models: ModelCatalog.bundledModels,
          ),
        ),
        GoRoute(
          path: AssistantRouteNames.modelAdvisorSegment,
          name: AssistantRouteNames.modelAdvisorName,
          builder: (context, state) => const ModelAdvisorScreen(),
        ),
        GoRoute(
          path: AssistantRouteNames.promptLabSegment,
          name: AssistantRouteNames.promptLabName,
          builder: (context, state) => PromptLabScreen(
            initialImageMode: state.uri.queryParameters['mode'] == 'image',
          ),
        ),
        GoRoute(
          path: AssistantRouteNames.audioScribeSegment,
          name: AssistantRouteNames.audioScribeName,
          builder: (context, state) => const AudioScribeScreen(),
        ),
        GoRoute(
          path: AssistantRouteNames.agentSkillsSegment,
          name: AssistantRouteNames.agentSkillsName,
          builder: (context, state) => const AgentSkillsScreen(),
        ),
        GoRoute(
          path: AssistantRouteNames.mobileActionsSegment,
          name: AssistantRouteNames.mobileActionsName,
          builder: (context, state) => const MobileActionsScreen(),
        ),
      ],
    ),
  ];

  /// Destinations the hub links out to that must not live inside the Mind
  /// navigation branch.
  ///
  /// Wellbeing split off the old Mind hub in milestone 22: three cards and a
  /// streak do not earn a slot in the bottom nav, so it is a pushed
  /// destination rather than a tab.
  List<RouteBase> rootRoutesFor(ShellId shell) => [
    GoRoute(
      path: AssistantRouteNames.wellbeing,
      name: AssistantRouteNames.wellbeingName,
      builder: (context, state) => const WellbeingScreen(),
    ),
  ];
}
