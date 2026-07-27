import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/widgets/offline_playback_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBanner(
    WidgetTester tester,
    Stream<List<ConnectivityResult>> stream,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connectivityStreamProvider.overrideWith((ref) => stream)],
        child: const MaterialApp(home: Scaffold(body: OfflinePlaybackBanner())),
      ),
    );
  }

  testWidgets('renders nothing while online', (tester) async {
    await pumpBanner(tester, Stream.value([ConnectivityResult.wifi]));
    await tester.pump();

    expect(find.byKey(const ValueKey('iptv-offline-banner')), findsNothing);
  });

  testWidgets('shows the offline banner once connectivity drops to none', (
    tester,
  ) async {
    final controller = StreamController<List<ConnectivityResult>>();
    addTearDown(controller.close);

    await pumpBanner(tester, controller.stream);
    controller.add([ConnectivityResult.wifi]);
    await tester.pump();

    expect(find.byKey(const ValueKey('iptv-offline-banner')), findsNothing);

    controller.add([ConnectivityResult.none]);
    await tester.pump();

    expect(find.byKey(const ValueKey('iptv-offline-banner')), findsOneWidget);
    expect(find.textContaining("You're offline"), findsOneWidget);
  });

  testWidgets('hides the banner again once connectivity is restored', (
    tester,
  ) async {
    final controller = StreamController<List<ConnectivityResult>>();
    addTearDown(controller.close);

    await pumpBanner(tester, controller.stream);
    controller.add([ConnectivityResult.none]);
    await tester.pump();
    expect(find.byKey(const ValueKey('iptv-offline-banner')), findsOneWidget);

    controller.add([ConnectivityResult.wifi]);
    await tester.pump();

    expect(find.byKey(const ValueKey('iptv-offline-banner')), findsNothing);
  });
}
