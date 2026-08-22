import '../../data/repositories/built_in_agent_skill_repository.dart';
import '../../data/repositories/shared_preferences_agent_skill_state_store.dart';
import '../../data/repositories/remote_agent_skill_store.dart';
import '../models/agent_skill.dart';
import 'skill_manifest_parser.dart';
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
    final remoteStore = RemoteAgentSkillStore(preferences);
    final imported = <AgentSkill>[];
    for (final document in remoteStore.loadDocuments()) {
      try {
        imported.add(
          SkillManifestParser.parse(
            document,
            skillSource: SkillSource.remote,
            installState: SkillInstallState.disabled,
          ),
        );
      } on SkillManifestFormatException {
        // Ignore invalid documents; the store remains repairable.
      }
    }
    return AgentSkillRegistry._(
      repository: BuiltInAgentSkillRepository(
        skills: [...(skills ?? builtInAgentSkills), ...imported],
        initialEnabledState: store.loadEnabledState(),
        onEnabledStateChanged: (enabledState) {
          store.saveEnabledState(enabledState);
        },
      ),
    );
  }

  List<AgentSkill> getAllSkills() => _repository.getAllSkills();

  List<AgentSkill> getEnabledSkills() => _repository.getEnabledSkills();

  List<AgentSkill> getToolSkills() =>
      getAllSkills().where((skill) => !skill.isPersona).toList();

  List<AgentSkill> getPersonas() =>
      getAllSkills().where((skill) => skill.isPersona).toList();

  AgentSkill? getById(String id) => _repository.getById(id);

  bool addSkill(AgentSkill skill) => _repository.addSkill(skill);

  void replaceSkill(AgentSkill skill) => _repository.replaceSkill(skill);

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
