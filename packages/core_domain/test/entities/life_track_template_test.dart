import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final template = LifeTrackTemplate(
    templateId: 'real_estate_under_construction_v1',
    title: 'Under-Construction Flat Purchase Checklist',
    description:
        '7 critical verification steps before buying an under-construction flat',
    category: LifeTrackCategory.realEstate,
    version: '1.0',
    milestones: const [
      MilestoneTemplate(
        name: 'Phase 1: RERA & Legal Verification',
        objective: 'Verify builder legitimacy and project approvals',
        tasks: [
          ActionItemTemplate(
            summary: 'Check Builder\'s RERA Registration',
            description: 'Look into the builder\'s track record.',
            requirements: [
              InputRequirementTemplate(
                label: 'RERA Registration Number',
                type: FieldType.text,
                isRequired: true,
                hint: 'Found on the RERA website',
              ),
            ],
          ),
        ],
      ),
    ],
  );

  test('round-trips template JSON', () {
    final encoded = template.toJson();
    final decoded = LifeTrackTemplate.fromJson(encoded);

    expect(decoded, template);
    expect(
      decoded.milestones.single.tasks.single.requirements.single.type,
      FieldType.text,
    );
  });

  test('parses template schema keys used by bundled and LLM blueprints', () {
    final decoded = LifeTrackTemplate.fromJson({
      'template_id': 'car_purchase_v1',
      'title': 'Car Purchase',
      'description': 'Template',
      'category': 'carPurchase',
      'version': '1.0',
      'milestones': [
        {
          'name': 'Documents',
          'objective': 'Prepare first',
          'tasks': [
            {
              'summary': 'Verify license',
              'requirements': [
                {
                  'label': 'Driving License',
                  'type': 'document',
                  'is_required': true,
                },
              ],
            },
          ],
        },
      ],
    });

    expect(decoded.category, LifeTrackCategory.carPurchase);
    expect(
      decoded.milestones.single.tasks.single.requirements.single.type,
      FieldType.document,
    );
  });
}
