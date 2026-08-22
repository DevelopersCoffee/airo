import 'package:feature_mind/src/addons/templates/addon_life_track_record_policy.dart';
import 'package:feature_mind/src/addons/templates/addon_template_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads workflow templates from compact JSONL bundle', () async {
    final catalog = await AddonTemplateCatalog.loadBundled();
    expect(
      catalog.templates.map((template) => template.templateId),
      containsAll([
        'insurance_claim_v1',
        'medical_surgery_v1',
        'real_estate_under_construction_v1',
        'car_purchase_v1',
        'university_admission_v1',
      ]),
    );
  });

  test('addon metadata supplies keywords and record follow-up copy', () async {
    final catalog = await AddonTemplateCatalog.loadBundled();
    final policy = AddonLifeTrackRecordPolicy(catalog);
    expect(
      policy.followUpHint('insurance_claim_v1'),
      contains('pending on this claim'),
    );
    expect(policy.dedupeFieldLabels('insurance_claim_v1'), contains('Claim ID'));
    expect(
      fallbackKeywordsFromCatalog(catalog)['real_estate_under_construction_v1'],
      contains('rera'),
    );
  });

  test('mind template loader merges core and addon templates', () async {
    final registry = await MindTemplateRegistryLoader().load();
    expect(registry.getById('insurance_claim_v1'), isNotNull);
    expect(registry.getById('car_purchase_v1'), isNotNull);
    expect(registry.getById('university_admission_v1'), isNotNull);
    expect(registry.getById('study_progress_v1'), isNotNull);
    expect(registry.getAll(), hasLength(6));
  });
}
