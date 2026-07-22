import 'dart:io';

import 'package:airo_app/main_airo_iptv.dart';
import 'package:feature_iptv/application/airo_tv_bootstrap.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'standalone IPTV entrypoint shares the TV XMLTV repository override',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final supportDir = await Directory.systemTemp.createTemp(
        'airo_standalone_iptv_epg_',
      );
      addTearDown(() async {
        if (await supportDir.exists()) {
          await supportDir.delete(recursive: true);
        }
      });
      final mutableRepository = MutableXmltvCompactEpgRepository();
      final compactRepository = createAiroTvCompactEpgRepository(
        supportDirectoryProvider: () async => supportDir,
        fallback: mutableRepository,
      );

      final container = ProviderContainer(
        overrides: buildStandaloneIptvProviderOverrides(
          prefs: prefs,
          compactEpgRepository: compactRepository,
          mutableXmltvRepository: mutableRepository,
        ),
      );
      addTearDown(container.dispose);

      expect(
        identical(
          container.read(mutableXmltvCompactEpgRepositoryProvider),
          mutableRepository,
        ),
        isTrue,
      );
      expect(
        identical(
          container.read(compactEpgRepositoryProvider),
          compactRepository,
        ),
        isTrue,
      );
    },
  );

  test(
    'standalone IPTV entrypoint initializes pro modules after first frame',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mutableRepository = MutableXmltvCompactEpgRepository();
      final compactRepository = createAiroTvCompactEpgRepository(
        fallback: mutableRepository,
      );
      final logs = <String>[];
      var proInitCalls = 0;
      void Function(Duration timestamp)? frameCallback;

      scheduleStandaloneIptvWarmups(
        prefs,
        compactEpgRepository: compactRepository,
        mutableXmltvRepository: mutableRepository,
        shouldWarmDebugPlaylist: false,
        epgUrl: '',
        addPostFrameCallback: (callback) {
          frameCallback = callback;
        },
        log: logs.add,
        initializeProModules: () async {
          proInitCalls++;
          return const ['pro-test'];
        },
      );

      expect(proInitCalls, 0);

      frameCallback!(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(proInitCalls, 1);
      expect(
        logs.where((log) => log.contains('pro bootstrap skipped')),
        isEmpty,
      );
    },
  );
}
