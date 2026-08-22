import 'dart:io';

import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/services/skill_manifest_parser.dart';

AgentSkill loadPluginSkillFixture(String id) {
  return SkillManifestParser.parse(
    File('skills/$id/SKILL.md').readAsStringSync(),
  );
}
