import '../../data/repositories/built_in_agent_skill_repository.dart';
import '../../data/repositories/shared_preferences_agent_skill_state_store.dart';
import '../models/agent_skill.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgentSkillRegistry {
  AgentSkillRegistry({List<AgentSkill>? skills})
    : _repository = BuiltInAgentSkillRepository(skills: skills);

  AgentSkillRegistry._({required this._repository});

  final BuiltInAgentSkillRepository _repository;

  static final builtInSkills = builtInAgentSkills;

  static Future<AgentSkillRegistry> loadPersisted({
    List<AgentSkill>? skills,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAgentSkillStateStore(preferences);
    return AgentSkillRegistry._(
      repository: BuiltInAgentSkillRepository(
        skills: skills,
        initialEnabledState: store.loadEnabledState(),
        onEnabledStateChanged: (enabledState) {
          store.saveEnabledState(enabledState);
        },
      ),
    );
  }

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
