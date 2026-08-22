import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AddonManifest parses spec example shape', () {
    final manifest = AddonManifest.fromJson({
      'schema_version': '1.0',
      'id': 'sample-addon',
      'version': '1.0.0',
      'behaviors': ['graph_workflow'],
      'capabilities': [
        'conversation.process',
        'lifetrack.read',
        'lifetrack.write',
      ],
      'tools': ['query_entity_graph', 'record_lifetrack_facts'],
      'safety_class': 'financial',
      'adapter': {
        'kind': 'required_built_in',
        'contract': 'graph_workflow_v1',
      },
      'workflow': {
        'template_asset': 'lifetrack_template.json',
        'subject_kind': 'subject',
      },
    });

    expect(manifest.id.value, 'sample-addon');
    expect(manifest.hasBehavior(AddonBehaviorKind.graphWorkflow), isTrue);
    expect(manifest.workflowSubjectKind, 'subject');
    expect(manifest.toJson()['id'], 'sample-addon');
  });
}
