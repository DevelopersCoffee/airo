import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/services/skill_manifest_parser.dart';
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

    test('parses a pinned persona without tools', () {
      const source = '''
---
id: lesson-planning-assistant
name: Lesson Planning
description: Draft lesson outlines.
version: 1.0.0
author: Airo
runtime: native
mode: persona
family: teacher
starter_prompts:
  - For Grade 6 science on ecosystems
---
You are a lesson planning assistant.
''';

      final skill = SkillManifestParser.parse(source);

      expect(skill.isPersona, isTrue);
      expect(skill.family, AgentPersonaFamily.teacher);
      expect(skill.tools, isEmpty);
      expect(skill.starterPrompts, ['For Grade 6 science on ecosystems']);
      expect(skill.instructions, contains('lesson planning assistant'));
    });

    test('parses life-workflow persona fields', () {
      const source = '''
---
id: hospital-recovery-planner
name: Hospital Recovery
description: Stage a hospital stay.
version: 1.0.0
author: Airo
runtime: native
mode: persona
family: health
safety_class: health
follow_up_policy: daily_until_done
life_track_template_id: medical_surgery_v1
starter_prompts:
  - What is pending on my hospital recovery track?
tools:
  - query_lifetrack_status
---
You are a hospital recovery assistant.
''';

      final skill = SkillManifestParser.parse(source);

      expect(skill.isPersona, isTrue);
      expect(skill.family, AgentPersonaFamily.health);
      expect(skill.followUpPolicy, SkillFollowUpPolicy.dailyUntilDone);
      expect(skill.lifeTrackTemplateId, 'medical_surgery_v1');
      expect(skill.tools, ['query_lifetrack_status']);
    });

    test('parses a Google AI Edge Gallery text-only skill as a persona', () {
      const source = '''
---
name: kitchen-adventure
description: Act as a dungeon master for a text-based adventure set in a world where everyone is a sentient kitchen appliance. Trigger when user says "start kitchen adventure".
---

# Kitchen Adventure

When the user initiates a session, you must transform into the Head Chef (DM).
''';

      final skill = SkillManifestParser.parse(source);

      expect(skill.id, 'kitchen-adventure');
      expect(skill.name, 'Kitchen Adventure');
      expect(skill.isPersona, isTrue);
      expect(skill.tools, isEmpty);
      expect(skill.manifest.version, '1.0.0');
      expect(skill.manifest.author, 'Community');
      expect(skill.instructions, contains('Head Chef'));
    });

    test('parses Gallery metadata maps without treating them as lists', () {
      const source = '''
---
name: fitness-coach
description: A cheerful fitness coach.
metadata:
  homepage: https://github.com/example/fitness-coach
---

# Cheerful Fitness Coach

You are an enthusiastic fitness coach.
''';

      final skill = SkillManifestParser.parse(source);
      expect(skill.id, 'fitness-coach');
      expect(skill.isPersona, isTrue);
    });

    test('rejects Gallery JavaScript and native-intent skills', () {
      const js = '''
---
name: query-wikipedia
description: Query summary from Wikipedia for a given topic.
---

Call the `run_js` tool using `index.html`.
''';
      const intent = '''
---
name: send-email
description: Send an email.
---

Call the `run_intent` tool with intent: send_email.
''';
      const secret = '''
---
name: mood-music
description: Play music.
metadata:
  require-secret: true
---

Suggest music for the user's mood.
''';

      expect(
        () => SkillManifestParser.parse(js),
        throwsA(isA<SkillManifestFormatException>()),
      );
      expect(
        () => SkillManifestParser.parse(intent),
        throwsA(isA<SkillManifestFormatException>()),
      );
      expect(
        () => SkillManifestParser.parse(secret),
        throwsA(isA<SkillManifestFormatException>()),
      );
    });
  });
}
