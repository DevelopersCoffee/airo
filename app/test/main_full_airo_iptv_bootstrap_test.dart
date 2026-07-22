import 'package:airo_app/main.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'full Airo schedules the shared IPTV XMLTV bootstrap after first frame',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mutableRepository = MutableXmltvCompactEpgRepository();
      final logs = <String>[];
      var refreshCalls = 0;
      void Function(Duration timestamp)? frameCallback;

      scheduleFullAiroIptvBootstrap(
        prefs,
        mutableXmltvRepository: mutableRepository,
        addPostFrameCallback: (callback) {
          frameCallback = callback;
        },
        log: logs.add,
        refreshConfiguredSource: () async {
          refreshCalls++;
        },
      );

      expect(refreshCalls, 0);

      frameCallback!(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(refreshCalls, 1);
      expect(
        logs,
        contains('✅ Deferred startup task completed: full_airo_iptv_bootstrap'),
      );
    },
  );
}
