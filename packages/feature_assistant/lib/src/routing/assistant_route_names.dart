/// Route paths owned by the assistant package.
///
/// Every shell that mounts the assistant (the super app and the standalone
/// Airo Mind shell) mounts these exact paths, so deep links, notification
/// payloads, and in-package navigation resolve identically everywhere.
/// The app's `RouteNames` references these constants rather than repeating
/// the literals, so the two can never drift apart.
class AssistantRouteNames {
  const AssistantRouteNames._();

  /// Assistant hub — the branch root.
  static const String assistant = '/assistant';
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

  /// Wellbeing is a destination rather than a tab, so it sits at the root.
  static const String wellbeing = '/wellbeing';

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
}
