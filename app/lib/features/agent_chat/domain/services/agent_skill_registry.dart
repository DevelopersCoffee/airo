import '../../data/repositories/built_in_agent_skill_repository.dart';
import '../models/agent_skill.dart';

class AgentSkillRegistry {
  AgentSkillRegistry({List<AgentSkill>? skills})
    : _repository = BuiltInAgentSkillRepository(skills: skills);

  final BuiltInAgentSkillRepository _repository;

  static final builtInSkills = builtInAgentSkills;

  List<AgentSkill> getAllSkills() => _repository.getAllSkills();

  List<AgentSkill> getEnabledSkills() => _repository.getEnabledSkills();

  AgentSkill? getById(String id) => _repository.getById(id);

  List<AgentSkill> search(String query) => _repository.search(query);

  List<String> enabledSkillSummariesForPrompt() {
    return _repository.enabledSkillSummariesForPrompt();
  }

  void setSkillEnabled(String id, bool enabled) {
    _repository.setSkillEnabled(id, enabled);
  }

  void enableAll() {
    _repository.enableAll();
  }

  void disableAll() {
    _repository.disableAll();
  }
}
