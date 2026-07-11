import 'package:airo_app/core/cast/cast.dart';
import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');

  testWidgets('device picker shows discovered Cast devices', (tester) async {
    final fake = FakeAiroCastController(devices: const [tv]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [airoCastControllerProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: CastDevicePickerTestHost()),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cast to a device'), findsOneWidget);
    expect(find.text('Sony Bravia'), findsOneWidget);
  });

  testWidgets('mini controller shows active cast session', (tester) async {
    final media = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/live.m3u8'),
      contentType: 'application/x-mpegURL',
      title: 'P4U Music',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iptvCastProvider.overrideWith(
            (ref) => _StaticCastNotifier(
              IptvCastState(
                session: AiroCastSessionSnapshot.playing(
                  device: tv,
                  media: media,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: IptvCastMiniController()),
        ),
      ),
    );

    expect(find.text('Casting to Sony Bravia'), findsOneWidget);
    expect(find.text('P4U Music'), findsOneWidget);
  });
}

class CastDevicePickerTestHost extends StatelessWidget {
  const CastDevicePickerTestHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            showIptvCastDevicePicker(
              context: context,
              onDeviceSelected: (_) {},
            );
          },
          child: const Text('Open'),
        ),
      ),
    );
  }
}

class _StaticCastNotifier extends IptvCastNotifier {
  _StaticCastNotifier(IptvCastState initial)
    : super(
        controller: FakeAiroCastController(),
        adapter: const IptvCastMediaAdapter(),
      ) {
    state = initial;
  }
}
