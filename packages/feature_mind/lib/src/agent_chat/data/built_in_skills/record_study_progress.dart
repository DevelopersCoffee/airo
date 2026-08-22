import '../../domain/models/agent_skill.dart';

final recordStudyProgressSkill = AgentSkill(
  id: 'record-study-progress',
  name: 'Study Progress',
  description:
      'Store study progress locally as a LifeTrack journey — subject, last topic, next session.',
  instructions:
      'Use this when the user wants to store, save, or track study progress '
      'with Airo Mind. Call record_lifetrack_facts with template '
      'study_progress_v1. Do not invent a notes app, summarizer, or calendar '
      'study tracker. LifeTrack is the local workflow.',
  tools: const ['record_lifetrack_facts', 'query_lifetrack_status'],
  capabilities: const [
    SkillCapability.lifeTrackWrite,
    SkillCapability.lifeTrackRead,
  ],
  family: AgentPersonaFamily.education,
  lifeTrackTemplateId: 'study_progress_v1',
  starterPrompts: const [
    'Store my Java study progress',
    'I finished chapter 4 of DSA — save that',
  ],
);
