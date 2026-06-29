import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TemplateRegistry', () {
    test('loads bundled templates and validates their structure', () async {
      final registry = await TemplateRegistry.loadBundled();

      final templates = registry.getAll();
      expect(templates, hasLength(5));
      expect(
        templates.map((template) => template.templateId),
        contains('real_estate_under_construction_v1'),
      );
      expect(
        templates.map((template) => template.templateId),
        contains('car_purchase_v1'),
      );
    });

    test(
      'returns the real estate template by id with expected milestone/task counts',
      () async {
        final registry = await TemplateRegistry.loadBundled();

        final template = registry.getById('real_estate_under_construction_v1');

        expect(template, isNotNull);
        expect(template!.milestones, hasLength(4));
        final taskCount = template.milestones.fold<int>(
          0,
          (count, milestone) => count + milestone.tasks.length,
        );
        expect(taskCount, 7);
      },
    );

    test('filters templates by category', () async {
      final registry = await TemplateRegistry.loadBundled();

      final educationTemplates = registry.getByCategory(
        LifeTrackCategory.education,
      );

      expect(educationTemplates, hasLength(1));
      expect(educationTemplates.single.templateId, 'university_admission_v1');
    });

    test('validate returns field errors for invalid payloads', () {
      final result = TemplateRegistry.validate({
        'template_id': '',
        'title': '',
        'description': '',
        'category': 'custom',
        'version': '',
        'milestones': const [],
      });

      expect(result, isA<Err<LifeTrackTemplate>>());
      final error = (result as Err<LifeTrackTemplate>).error;
      expect(error, isA<ValidationError>());
      expect(
        (error as ValidationError).fieldErrors.keys,
        contains('milestones'),
      );
      expect(error.fieldErrors.keys, contains('title'));
    });
  });
}
