import 'package:feature_mind/src/agent_chat/data/repositories/remote_agent_skill_store.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/services/remote_agent_skill_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _document = '''
---
id: community-weather
name: Community Weather
description: Read a weather summary using a user-approved web tool.
version: 1.0.0
author: Community
runtime: native
capabilities:
  - web.fetch
tools:
  - fetch_weather
---
# Community Weather

Only run after the user asks for a weather summary.
''';

void main() {
  test(
    'accepts HTTPS documents, quarantines them, and persists them',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final skill = await RemoteAgentSkillInstaller(
        store: RemoteAgentSkillStore(preferences),
        fetcher: (_) async => _document,
      ).install('https://example.com/SKILL.md');

      expect(skill.id, 'community-weather');
      expect(skill.manifest.source, SkillSource.remote);
      expect(skill.manifest.installState, SkillInstallState.disabled);
      expect(RemoteAgentSkillStore(preferences).loadDocuments(), [_document]);
    },
  );

  test('rejects non-HTTPS URLs before fetching', () async {
    var fetched = false;
    final installer = RemoteAgentSkillInstaller(
      fetcher: (_) async {
        fetched = true;
        return _document;
      },
    );

    expect(
      () => installer.install('http://example.com/SKILL.md'),
      throwsA(isA<FormatException>()),
    );
    expect(fetched, isFalse);
  });

  test('resolves Gallery folder and GitHub tree URLs to SKILL.md', () {
    expect(
      resolveRemoteSkillDocumentUri(
        'https://skills.example.com/kitchen-adventure',
      ).toString(),
      'https://skills.example.com/kitchen-adventure/SKILL.md',
    );
    expect(
      resolveRemoteSkillDocumentUri(
        'https://github.com/google-ai-edge/gallery/tree/main/skills/built-in/kitchen-adventure',
      ).toString(),
      'https://raw.githubusercontent.com/google-ai-edge/gallery/main/skills/built-in/kitchen-adventure/SKILL.md',
    );
    expect(
      resolveRemoteSkillDocumentUri(
        'https://github.com/google-ai-edge/gallery/blob/main/skills/built-in/kitchen-adventure/SKILL.md',
      ).toString(),
      'https://raw.githubusercontent.com/google-ai-edge/gallery/main/skills/built-in/kitchen-adventure/SKILL.md',
    );
  });

  test('imports a Gallery text-only skill as a quarantined persona', () async {
    const gallery = '''
---
name: kitchen-adventure
description: Act as a dungeon master for a kitchen adventure.
---

# Kitchen Adventure

When the user initiates a session, you must transform into the Head Chef.
''';
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    Uri? requested;
    final skill =
        await RemoteAgentSkillInstaller(
          store: RemoteAgentSkillStore(preferences),
          fetcher: (uri) async {
            requested = uri;
            return gallery;
          },
        ).install(
          'https://github.com/google-ai-edge/gallery/tree/main/skills/built-in/kitchen-adventure',
        );

    expect(
      requested.toString(),
      'https://raw.githubusercontent.com/google-ai-edge/gallery/main/skills/built-in/kitchen-adventure/SKILL.md',
    );
    expect(skill.id, 'kitchen-adventure');
    expect(skill.isPersona, isTrue);
    expect(skill.manifest.installState, SkillInstallState.disabled);
  });

  test('rejects oversized remote documents', () async {
    final installer = RemoteAgentSkillInstaller(
      fetcher: (_) async => 'x' * (RemoteAgentSkillStore.maxDocumentBytes + 1),
    );

    expect(
      () => installer.install('https://example.com/SKILL.md'),
      throwsA(isA<FormatException>()),
    );
  });
}
