import 'package:airo_app/features/agent_chat/domain/models/agent_skill.dart';
import 'package:airo_app/features/agent_chat/domain/services/skill_manifest_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SkillManifestParser', () {
    test('parses YAML frontmatter and markdown instructions', () {
      const source = '''
---
id: calendar-today
name: Calendar Today
description: Read today's calendar events and summarize the user's schedule.
version: 1.0.0
author: Airo
runtime: native
capabilities:
  - calendar.read
tools:
  - get_current_date_time
  - read_calendar_events
---
# Calendar Today

Use this when the user asks about today's schedule.
''';

      final skill = SkillManifestParser.parse(source);

      expect(skill.manifest.id, 'calendar-today');
      expect(skill.manifest.name, 'Calendar Today');
      expect(skill.manifest.version, '1.0.0');
      expect(skill.manifest.author, 'Airo');
      expect(skill.manifest.runtime, SkillRuntime.native);
      expect(skill.manifest.source, SkillSource.builtIn);
      expect(skill.manifest.installState, SkillInstallState.enabled);
      expect(skill.manifest.capabilities, [SkillCapability.calendarRead]);
      expect(skill.manifest.tools, [
        'get_current_date_time',
        'read_calendar_events',
      ]);
      expect(skill.instructions, contains('# Calendar Today'));
      expect(skill.summaryForPrompt, contains('calendar-today'));
    });

    test('rejects missing required fields', () {
      const source = '''
---
id: calendar-today
name: Calendar Today
runtime: native
capabilities:
  - calendar.read
tools:
  - read_calendar_events
---
Instructions.
''';

      expect(
        () => SkillManifestParser.parse(source),
        throwsA(isA<SkillManifestFormatException>()),
      );
    });

    test('rejects non kebab-case skill ids', () {
      const source = '''
---
id: Calendar_Today
name: Calendar Today
description: Read today's calendar events.
version: 1.0.0
author: Airo
runtime: native
capabilities:
  - calendar.read
tools:
  - read_calendar_events
---
Instructions.
''';

      expect(
        () => SkillManifestParser.parse(source),
        throwsA(isA<SkillManifestFormatException>()),
      );
    });

    test('rejects unknown capabilities and runtimes', () {
      const source = '''
---
id: unsafe-skill
name: Unsafe Skill
description: Attempts an unsupported capability.
version: 1.0.0
author: Airo
runtime: shell
capabilities:
  - device.delete
tools:
  - delete_everything
---
Instructions.
''';

      expect(
        () => SkillManifestParser.parse(source),
        throwsA(isA<SkillManifestFormatException>()),
      );
    });
  });
}
