import '../../../runtime/models/capability_models.dart';
import '../models/agent_skill.dart';

/// Maps a skill's declared capabilities to the safety banner it must carry.
///
/// Driven by the capability, not the screen: any surface that renders an
/// answer backed by a health-class capability shows the same wellness-only
/// notice, wherever that surface lives. Adding a new safety-classed
/// capability means adding one entry here, not hardcoding a banner per
/// screen.
CapabilitySafetyClass? resolveCapabilitySafetyClass(
  List<SkillCapability> capabilities,
) {
  for (final capability in capabilities) {
    final safetyClass = _safetyClassByCapability[capability];
    if (safetyClass != null && safetyClass != CapabilitySafetyClass.general) {
      return safetyClass;
    }
  }
  return null;
}

/// LifeTrack goals can carry health-adjacent tracking (medicine schedules,
/// recovery milestones), so a LifeTrack-read answer must carry the
/// wellness-only notice. No other built-in capability today claims a
/// financial or legal safety class.
const Map<SkillCapability, CapabilitySafetyClass> _safetyClassByCapability = {
  SkillCapability.lifeTrackRead: CapabilitySafetyClass.health,
};
