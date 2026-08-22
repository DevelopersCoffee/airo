import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TemplateRegistry', () {
    test('loads no framework bundled templates after addon migration', () async {
      final registry = await TemplateRegistry.loadBundled();
      expect(registry.getAll(), isEmpty);
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
    });
  });
}
