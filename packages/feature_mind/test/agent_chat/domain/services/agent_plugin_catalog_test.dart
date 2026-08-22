import 'dart:io';

import 'package:feature_mind/src/agent_chat/data/repositories/built_in_agent_skill_repository.dart';
import 'package:feature_mind/src/agent_chat/data/repositories/remote_agent_skill_store.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_plugin_catalog.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_plugin_catalog_loader.dart';
import 'package:feature_mind/src/agent_chat/domain/services/plugin_version.dart';
import 'package:feature_mind/src/agent_chat/domain/services/remote_agent_skill_installer.dart';
import 'package:feature_mind/src/agent_chat/domain/services/skill_manifest_parser.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('built-in skills do not ship specialist personas', () {
    expect(builtInAgentSkills.where((skill) => skill.isPersona), isEmpty);
  });

  test('catalog and SKILL.md plugins parse with versions', () {
    final catalog = AgentPluginCatalog.parse(
      File('skills/catalog.json').readAsStringSync(),
    );
    expect(catalog.entries, isNotEmpty);
    for (final entry in catalog.entries) {
      expect(entry.url, startsWith('https://'));
      expect(entry.version, isNotEmpty);
      final skill = SkillManifestParser.parse(
        File('skills/${entry.id}/SKILL.md').readAsStringSync(),
      );
      expect(skill.id, entry.id);
      expect(skill.name, entry.name);
      expect(skill.version, entry.version);
      expect(skill.isPersona, isTrue);
    }
  });

  test('catalog loader prefers a newer remote snapshot', () async {
    final bundled = File('skills/catalog.json').readAsStringSync();
    final remote = bundled.replaceFirst(
      '"version": "1.0.0"',
      '"version": "1.1.0"',
    );
    final catalog = await AgentPluginCatalogLoader(
      bundledCatalog: bundled,
      fetcher: (_) async => remote,
      remoteUrl: 'https://example.com/catalog.json',
    ).load();
    expect(catalog.entries.first.version, '1.1.0');
  });

  test('catalog loader falls back to the bundled index offline', () async {
    final bundled = File('skills/catalog.json').readAsStringSync();
    final catalog = await AgentPluginCatalogLoader(
      bundledCatalog: bundled,
      fetcher: (_) async => throw const SocketException('offline'),
      remoteUrl: 'https://example.com/catalog.json',
    ).load();
    expect(catalog.entries, isNotEmpty);
    expect(catalog.entries.first.version, '1.0.0');
  });

  test('newer plugin versions compare by semver', () {
    expect(pluginVersionIsNewer('1.1.0', '1.0.0'), isTrue);
    expect(pluginVersionIsNewer('1.0.0', '1.0.0'), isFalse);
    expect(comparePluginVersions('2.0.0', '1.9.9'), 1);
  });

  test(
    'catalog install enables the plugin and replaces by id on update',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = RemoteAgentSkillStore(preferences);
      final v1 = File(
        'skills/hospital-recovery-planner/SKILL.md',
      ).readAsStringSync();
      final installedVersion = SkillManifestParser.parse(v1).version;
      final v2 = v1.replaceFirst(
        'version: $installedVersion',
        'version: 9.9.9',
      );
      final installer = RemoteAgentSkillInstaller(
        store: store,
        fetcher: (_) async => v1,
      );
      const entry = AgentPluginCatalogEntry(
        id: 'hospital-recovery-planner',
        name: 'Hospital Recovery',
        description: 'Stage a surgery or hospital stay.',
        version: '1.0.0',
        family: AgentPersonaFamily.health,
        safetyClass: CapabilitySafetyClass.health,
        author: 'Airo',
        url: 'https://example.com/hospital-recovery-planner/SKILL.md',
      );

      final installed = await installer.installFromCatalog(entry);
      expect(installed.isEnabled, isTrue);
      expect(installed.version, installedVersion);
      expect(store.loadRecords().single.version, installedVersion);

      final updated = await RemoteAgentSkillInstaller(
        store: store,
        fetcher: (_) async => v2,
      ).installFromCatalog(entry);
      expect(updated.version, '9.9.9');
      expect(store.loadRecords(), hasLength(1));
      expect(store.loadRecords().single.version, '9.9.9');
    },
  );
}
