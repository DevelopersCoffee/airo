import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SkillPermissionEngine', () {
    late SkillPermissionEngine engine;

    setUp(() {
      engine = const SkillPermissionEngine();
    });

    test(
      'defaults unknown tools to blocked with a redacted decision trace',
      () {
        final decision = engine.resolve(
          const SkillActionRequest(
            toolId: 'unknown.tool',
            domain: SkillActionDomain.unknown,
            operation: SkillActionOperation.read,
            source: SkillActionSource.builtIn,
            payloadPreview: 'secret token 123 should not be copied',
          ),
        );

        expect(decision.tier, SkillTrustTier.blocked);
        expect(decision.canExecute, isFalse);
        expect(decision.requiresConfirmation, isFalse);
        expect(decision.trace.toolId, 'unknown.tool');
        expect(decision.trace.reason, contains('Unknown tool'));
        expect(decision.trace.redactedPayload, isNull);
      },
    );

    test('allows known read-only calendar reads without confirmation', () {
      final decision = engine.resolve(
        const SkillActionRequest(
          toolId: 'calendar.events.list',
          domain: SkillActionDomain.calendar,
          operation: SkillActionOperation.read,
          source: SkillActionSource.builtIn,
        ),
      );

      expect(decision.tier, SkillTrustTier.readOnly);
      expect(decision.canExecute, isTrue);
      expect(decision.requiresConfirmation, isFalse);
      expect(decision.trace.reason, contains('read-only'));
    });

    test(
      'requires confirmation for reminder writes without scoped automation',
      () {
        final decision = engine.resolve(
          const SkillActionRequest(
            toolId: 'reminders.create',
            domain: SkillActionDomain.reminders,
            operation: SkillActionOperation.create,
            source: SkillActionSource.builtIn,
          ),
        );

        expect(decision.tier, SkillTrustTier.confirmationRequired);
        expect(decision.canExecute, isFalse);
        expect(decision.requiresConfirmation, isTrue);
      },
    );

    test('auto-approves reminder writes inside a valid scoped automation', () {
      final decision = engine.resolve(
        const SkillActionRequest(
          toolId: 'reminders.create',
          domain: SkillActionDomain.reminders,
          operation: SkillActionOperation.create,
          source: SkillActionSource.builtIn,
          automationScope: SkillAutomationScope(
            id: 'morning-routine',
            allowedDomains: [SkillActionDomain.reminders],
            allowedOperations: [SkillActionOperation.create],
          ),
        ),
      );

      expect(decision.tier, SkillTrustTier.autoApproved);
      expect(decision.canExecute, isTrue);
      expect(decision.requiresConfirmation, isFalse);
      expect(decision.trace.automationScopeId, 'morning-routine');
    });

    test('keeps community skill actions in draft-only mode by default', () {
      final decision = engine.resolve(
        const SkillActionRequest(
          toolId: 'calendar.events.list',
          domain: SkillActionDomain.calendar,
          operation: SkillActionOperation.read,
          source: SkillActionSource.community,
        ),
      );

      expect(decision.tier, SkillTrustTier.draftOnly);
      expect(decision.canExecute, isFalse);
      expect(decision.requiresConfirmation, isFalse);
      expect(decision.trace.reason, contains('Community'));
    });

    test('blocks destructive finance and file-system actions', () {
      final transfer = engine.resolve(
        const SkillActionRequest(
          toolId: 'finance.transfer.execute',
          domain: SkillActionDomain.finance,
          operation: SkillActionOperation.transfer,
          source: SkillActionSource.builtIn,
        ),
      );
      final deleteFile = engine.resolve(
        const SkillActionRequest(
          toolId: 'files.delete',
          domain: SkillActionDomain.fileSystem,
          operation: SkillActionOperation.delete,
          source: SkillActionSource.builtIn,
        ),
      );

      expect(transfer.tier, SkillTrustTier.blocked);
      expect(transfer.canExecute, isFalse);
      expect(deleteFile.tier, SkillTrustTier.blocked);
      expect(deleteFile.canExecute, isFalse);
    });
  });
}
