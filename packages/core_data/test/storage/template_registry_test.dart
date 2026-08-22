import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TemplateRegistry', () {
    test('loads bundled templates and validates their structure', () async {
      final registry = await TemplateRegistry.loadBundled();

      final templates = registry.getAll();
      expect(templates, hasLength(1));
      expect(
        templates.map((template) => template.templateId),
        contains('study_progress_v1'),
      );
    });

    test('filters templates by category', () async {
      final registry = await TemplateRegistry.loadBundled();

      final educationTemplates = registry.getByCategory(
        LifeTrackCategory.education,
      );

      expect(educationTemplates, hasLength(1));
      expect(
        educationTemplates.map((template) => template.templateId),
        contains('study_progress_v1'),
      );
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
