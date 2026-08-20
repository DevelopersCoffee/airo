/// Route paths owned by the Mind package.
///
/// Every shell that mounts the hub (the super app and the standalone Airo Mind
/// shell) mounts these exact paths, so deep links, notification payloads, and
/// in-package navigation resolve identically everywhere. The app's `RouteNames`
/// references these constants rather than repeating the literals, so the two
/// can never drift apart.
///
/// # The hub lives at `/mind`
///
/// Phase 3 of the SSOT plan claimed `/mind` for its intended owner. Everything
/// below derives from the one root constant, so the move is that constant and
/// nothing else -- which is the whole reason the paths were centralised here
/// before the move rather than during it.
///
/// The route **names** did not change and must not. Deep links, notification
/// payloads and every `goNamed`/`namedLocation` call site resolve on names, not
/// paths; renaming one is a breaking change for every shell and for
/// notifications already sitting in the OS. `assistantName = 'Assistant'` is
/// deliberately still spelled that way for exactly that reason.
class AssistantRouteNames {
  const AssistantRouteNames._();

  /// The Mind hub — the branch root. Every path below is built from it.
  ///
  /// Was `/assistant` until Phase 3. Old links keep working: the router
  /// redirects `/assistant/*`, and notification payloads are migrated in
  /// `notification_navigation_service.dart`.
  static const String assistant = '/mind';
  static const String chat = '$assistant/$chatSegment';
  static const String notifications = '$assistant/$notificationsSegment';
  static const String profile = '$assistant/$profileSegment';
  static const String models = '$assistant/$modelsSegment';
  static const String deviceCapabilities =
      '$assistant/$deviceCapabilitiesSegment';
  static const String modelAdvisor = '$assistant/$modelAdvisorSegment';
  static const String promptLab = '$assistant/$promptLabSegment';
  static const String audioScribe = '$assistant/$audioScribeSegment';
  static const String agentSkills = '$assistant/$agentSkillsSegment';
  static const String mobileActions = '$assistant/$mobileActionsSegment';
  static const String calendar = '$assistant/$calendarSegment';

  /// Wellbeing is a destination rather than a tab, so it sits at the root.
  static const String wellbeing = '/wellbeing';

  // GoRouter route *names*. Deep links, notification payloads, and existing
  // `goNamed`/`namedLocation` call sites resolve on these, so the literals
  // below are frozen: they are the pre-extraction super-app names, not a
  // tidied-up scheme. Renaming one is a breaking change for every shell.
  static const String assistantName = 'Assistant';
  static const String chatName = 'assistant_chat';
  static const String notificationsName = 'agent_notifications';
  static const String profileName = 'profile';
  static const String modelsName = 'assistant_models';
  static const String deviceCapabilitiesName = 'assistant_device_capabilities';
  static const String modelAdvisorName = 'assistant_model_advisor';
  static const String promptLabName = 'assistant_prompt_lab';
  static const String audioScribeName = 'assistant_audio_scribe';
  static const String agentSkillsName = 'assistant_agent_skills';
  static const String mobileActionsName = 'assistant_mobile_actions';
  static const String calendarName = 'assistant_calendar';
  static const String wellbeingName = 'Wellbeing';

  // Child segments, for shells that declare the routes as nested `GoRoute`s.
  static const String chatSegment = 'chat';
  static const String notificationsSegment = 'notifications';
  static const String profileSegment = 'profile';
  static const String modelsSegment = 'models';
  static const String deviceCapabilitiesSegment = 'device-capabilities';
  static const String modelAdvisorSegment = 'model-advisor';
  static const String promptLabSegment = 'prompt-lab';
  static const String audioScribeSegment = 'audio-scribe';
  static const String agentSkillsSegment = 'skills';
  static const String mobileActionsSegment = 'mobile-actions';
  static const String calendarSegment = 'calendar';
}
