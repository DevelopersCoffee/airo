import 'package:airo_app/main_tv.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _productNameProvider = Provider<String>((ref) => 'Airo');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'TV entrypoint appends provider overrides contributed by bootstrap',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mutableRepo = MutableXmltvCompactEpgRepository();

      final container = ProviderContainer(
        overrides: buildTvProviderOverrides(
          prefs: prefs,
          compactEpgRepository: createTvCompactEpgRepository(
            fallback: mutableRepo,
          ),
          mutableXmltvRepository: mutableRepo,
          proProviderOverrides: [
            _productNameProvider.overrideWithValue('Airo Pro'),
          ],
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(_productNameProvider), 'Airo Pro');
    },
  );
}
