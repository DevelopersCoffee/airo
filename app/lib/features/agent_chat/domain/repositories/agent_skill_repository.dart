import '../models/agent_skill.dart';

abstract interface class AgentSkillRepository {
  List<AgentSkill> getAllSkills();
  List<AgentSkill> getEnabledSkills();
  AgentSkill? getById(String id);
  List<AgentSkill> search(String query);
  List<String> enabledSkillSummariesForPrompt();
  void setSkillEnabled(String id, bool enabled);
  void enableAll();
  void disableAll();
}
