import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LifeTrackTemplateFallbackResolver', () {
    late TemplateRegistry registry;
    late _FakeConnectivityService connectivityService;
    late LifeTrackTemplateFallbackResolver resolver;

    setUp(() {
      registry = TemplateRegistry.fromTemplates([
        _template(
          templateId: 'real_estate_under_construction_v1',
          title: 'Flat purchase',
          category: LifeTrackCategory.realEstate,
        ),
        _template(
          templateId: 'medical_surgery_v1',
          title: 'Medical surgery',
          category: LifeTrackCategory.medical,
        ),
        _template(
          templateId: 'university_admission_v1',
          title: 'University admission',
          category: LifeTrackCategory.education,
        ),
      ]);
      connectivityService = _FakeConnectivityService();
      resolver = LifeTrackTemplateFallbackResolver(
        registry: registry,
        connectivityService: connectivityService,
      );
    });

    test(
      'returns no fallback when online and generation has not failed',
      () async {
        final result = await resolver.resolve('I need help buying a flat');

        expect(result.status, LifeTrackTemplateFallbackStatus.noFallbackNeeded);
        expect(result.shouldFallback, isFalse);
        expect(result.template, isNull);
      },
    );

    test('recommends real estate template when offline', () async {
      connectivityService.connected = false;

      final result = await resolver.resolve('I need help buying a flat');

      expect(result.status, LifeTrackTemplateFallbackStatus.recommended);
      expect(result.reason, LifeTrackTemplateFallbackReason.offline);
      expect(result.template?.templateId, 'real_estate_under_construction_v1');
      expect(result.matchedKeywords, contains('flat'));
    });

    test('recommends medical template when generation fails', () async {
      final result = await resolver.resolve(
        'Need doctor and operation paperwork',
        generationFailure: StateError('local llm failed'),
      );

      expect(result.status, LifeTrackTemplateFallbackStatus.recommended);
      expect(result.reason, LifeTrackTemplateFallbackReason.generationFailed);
      expect(result.template?.templateId, 'medical_surgery_v1');
      expect(result.matchedKeywords, containsAll(['doctor', 'operation']));
    });

    test('matches education synonym phrases deterministically', () async {
      connectivityService.connected = false;

      final result = await resolver.resolve(
        'Need a plan for university enrollment and visa steps',
      );

      expect(result.status, LifeTrackTemplateFallbackStatus.recommended);
      expect(result.template?.templateId, 'university_admission_v1');
      expect(result.matchedKeywords, containsAll(['university', 'enrollment']));
    });

    test(
      'returns explicit no-match when fallback is needed but no keywords match',
      () async {
        connectivityService.connected = false;

        final result = await resolver.resolve(
          'Help me organize my photography side project',
        );

        expect(result.status, LifeTrackTemplateFallbackStatus.noMatch);
        expect(result.reason, LifeTrackTemplateFallbackReason.offline);
        expect(result.template, isNull);
        expect(result.matchedKeywords, isEmpty);
        expect(result.shouldFallback, isTrue);
      },
    );
  });
}

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService() : super();

  bool connected = true;

  @override
  Future<bool> get isConnected async => connected;
}

LifeTrackTemplate _template({
  required String templateId,
  required String title,
  required LifeTrackCategory category,
}) {
  return LifeTrackTemplate(
    templateId: templateId,
    title: title,
    description: '$title template',
    category: category,
    version: '1.0',
    milestones: const [
      MilestoneTemplate(
        name: 'Phase 1',
        objective: 'Objective',
        tasks: [
          ActionItemTemplate(
            summary: 'Task',
            requirements: [
              InputRequirementTemplate(
                label: 'Notes',
                type: FieldType.text,
                isRequired: true,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
