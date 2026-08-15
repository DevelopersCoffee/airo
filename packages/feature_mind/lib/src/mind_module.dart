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
import 'capture/presentation/meeting_capture_screen.dart';
import 'host/assistant_host_adapter.dart';
import 'mind_home_screen.dart';
import 'mind_service.dart';
import 'routing/assistant_route_names.dart';
import 'wellbeing/presentation/screens/wellbeing_screen.dart';

/// Builds the host adapter for a shell, given that shell's Riverpod [Ref].
///
/// A factory rather than a ready-made instance: a host adapter is normally a
/// thin wrapper over the shell's own providers (settings, auth, finance), so
/// it needs the `Ref` that only exists once the `ProviderContainer` is being
/// built. Shells pass a constructor tear-off, e.g.
/// `MindModule(hostAdapterBuilder: AppAssistantHostAdapter.new)`.
typedef AssistantHostAdapterBuilder = AssistantHostAdapter Function(Ref ref);

/// The Airo Mind tab, as a shell-agnostic module.
///
/// Merges what used to be two modules — `AssistantModule` (the chat/models/
/// prompt-lab/wellbeing hub) and `MindScribeModule` (record → transcribe →
/// minutes → search) — into one, since both are now the same package
/// (`docs/superpowers/plans/2026-08-07-airo-mind-ssot-plan.md`, Phase 2). A
/// shell that never passes [createService] gets the hub only, exactly the
/// mobile shell's behaviour before the merge; the standalone Mind shell passes
/// it and gets the scribe root route too.
///
/// * [hubRoutesFor] — the assistant hub and its children, which a shell mounts
///   inside whatever navigation branch shows the Mind tab.
/// * [rootRoutesFor] — destinations that are reached *from* the hub but are not
///   part of it, currently only Wellbeing. These must sit at the shell's top
///   level: Wellbeing is a full-screen destination, and mounting it inside the
///   Mind branch would wrap it in the super app's bottom navigation.
/// * [scribeRoutesFor] — the meeting recorder, mounted at `/` and only
///   contributed when [createService] is supplied. The standalone shell reaches
///   the scribe this way; the super app does not yet (Phase 4).
///
/// [routesFor] returns all three, so [ModuleRegistry] still sees the module's
/// complete path/name surface for conflict detection. Shells that need the
/// distinction call the accessors instead of splitting the combined list by
/// path.
///
/// The hub's mount points are fixed at [AssistantRouteNames]'s canonical paths
/// and are deliberately not configurable. Every shell mounts the assistant at
/// `/assistant` so deep links, notification payloads, and the tool registry
/// resolve identically everywhere — and the package's own screens navigate by
/// those absolute paths, so a rebased mount would 404 its own hub tiles.
class MindModule extends AppModule {
  MindModule({
    required this.hostAdapterBuilder,
    this.createService,
    this.scribeOverrides,
  });

  /// Builds the shell's implementation of the assistant's host seam.
  final AssistantHostAdapterBuilder hostAdapterBuilder;

  /// Overrides the composing shell contributes about the scribe's models,
  /// given the [service] whose directory says what is really installed.
  ///
  /// Supplied by the shell rather than built here because the provider they
  /// override is an app-layer one this package cannot see: the Mind shell puts
  /// the scribe's weights in its shared model explorer (#1556). Passing it
  /// here rather than dropping the overrides straight into the shell's
  /// `ProviderScope` keeps the registry the one thing that knows what a
  /// module contributes — and keeps the rows off any shell that does not ask
  /// for them, which is why the super app's model manager still lists only
  /// its own chat models.
  final List<Override> Function(MindService service)? scribeOverrides;

  /// The scribe's service factory. Null means this shell instance does not
  /// carry the scribe — [scribeRoutesFor] then contributes nothing, and
  /// [service] is never touched. Which app ships the scribe route is a shell
  /// composition decision, not something this module defaults.
  final MindService Function()? createService;

  MindService? _service;

  /// The scribe's service, created on first use and torn down by [dispose].
  /// Only valid to call when [createService] was supplied.
  MindService get service => _service ??= createService!();

  @override
  String get id => 'mind';

  /// Phone-class shells only, matching `module.yaml` (`tv: Never Ship`).
  @override
  Set<ShellId> get supportedShells => {ShellId.mobile, ShellId.mind};

  /// The module owns installing its own host seam, so a shell can never mount
  /// the assistant's routes while forgetting the adapter they depend on.
  @override
  List<Override> providerOverridesFor(ShellId shell) => [
    assistantHostAdapterProvider.overrideWith(hostAdapterBuilder),
    // Scribe-shaped overrides only exist where the scribe does: a shell with
    // no [createService] has no models directory to report on.
    if (createService != null && scribeOverrides != null)
      ...scribeOverrides!(service),
  ];

  @override
  Future<void> initialize() async {
    // Touching the getter is the initialization: it builds the recorder and
    // the installer so the first tap on Record is not also the first time the
    // platform channel is opened. A shell that never passed a factory has
    // nothing to initialize here.
    if (createService != null) service;
  }

  @override
  Future<void> dispose() async {
    await _service?.dispose();
    _service = null;
  }

  @override
  List<RouteBase> routesFor(ShellId shell) => [
    ...hubRoutesFor(shell),
    ...rootRoutesFor(shell),
    ...scribeRoutesFor(shell),
  ];

  /// The meeting recorder, mounted at the shell's root. Contributed only when
  /// [createService] was supplied — today, the standalone Mind shell.
  List<RouteBase> scribeRoutesFor(ShellId shell) => [
    if (createService != null)
      GoRoute(
        path: '/',
        name: 'mind_scribe',
        builder: (context, state) => MindHomeScreen(service: service),
        routes: [
          // In-app capture (#1656): pause/resume, incremental disk writes,
          // consent UX, the mic-privacy-respecting Android foreground
          // service, and hand-off to the resumable processing queue.
          // `MindHomeScreen`'s own record button (`MindService.startRecording`)
          // is the pre-#1656 single-shot path and is left as-is; this is the
          // upgraded route.
          GoRoute(
            path: 'record',
            name: 'mind_meeting_capture',
            builder: (context, state) => const MeetingCaptureScreen(),
          ),
        ],
      ),
  ];

  /// The assistant hub and everything nested under it.
  List<RouteBase> hubRoutesFor(ShellId shell) => [
    GoRoute(
      path: AssistantRouteNames.assistant,
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
          builder: (context, state) => Consumer(
            builder: (context, ref, _) => ModelLibraryScreen(
              onModelSelected: (candidate) =>
                  context.go(AssistantRouteNames.assistant),
              onOpenModelManager: () => ref
                  .read(assistantHostAdapterProvider)
                  .openModelManager(context),
            ),
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
