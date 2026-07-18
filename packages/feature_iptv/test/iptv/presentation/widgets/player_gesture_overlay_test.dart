import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/presentation/widgets/player_gesture_overlay.dart';

void main() {
  // MaterialApp/Navigator gives `home` TIGHT constraints from the test
  // surface (800x600 by default) — wrapping it in a SizedBox doesn't shrink
  // it, since tight constraints always win. Shrinking the actual test
  // surface via `tester.view` is the only way to control the viewport the
  // gesture zones split against.
  Future<void> pumpOverlay(
    WidgetTester tester, {
    bool locked = false,
    double brightness = 0.5,
    double volume = 0.5,
    ValueChanged<double>? onBrightnessChanged,
    ValueChanged<double>? onVolumeChanged,
  }) {
    tester.view.physicalSize = const Size(300, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      MaterialApp(
        home: PlayerGestureOverlay(
          locked: locked,
          brightness: brightness,
          volume: volume,
          onBrightnessChanged: onBrightnessChanged ?? (_) {},
          onVolumeChanged: onVolumeChanged ?? (_) {},
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
  }

  testWidgets(
    'dragging up on the left half increases brightness and never touches volume',
    (tester) async {
      final brightnessValues = <double>[];
      final volumeValues = <double>[];
      await pumpOverlay(
        tester,
        brightness: 0.5,
        onBrightnessChanged: brightnessValues.add,
        onVolumeChanged: volumeValues.add,
      );

      // Left quarter of the 300-wide surface is the brightness zone.
      await tester.dragFrom(const Offset(50, 300), const Offset(0, -120));
      await tester.pump();

      expect(volumeValues, isEmpty);
      expect(brightnessValues, isNotEmpty);
      expect(brightnessValues.last, greaterThan(0.5));
    },
  );

  testWidgets(
    'dragging down on the right half decreases volume and never touches brightness',
    (tester) async {
      final brightnessValues = <double>[];
      final volumeValues = <double>[];
      await pumpOverlay(
        tester,
        volume: 0.5,
        onBrightnessChanged: brightnessValues.add,
        onVolumeChanged: volumeValues.add,
      );

      // Right quarter of the 300-wide surface is the volume zone.
      await tester.dragFrom(const Offset(250, 100), const Offset(0, 120));
      await tester.pump();

      expect(brightnessValues, isEmpty);
      expect(volumeValues, isNotEmpty);
      expect(volumeValues.last, lessThan(0.5));
    },
  );

  testWidgets('shows a value indicator while dragging', (tester) async {
    await pumpOverlay(tester);

    final gesture = await tester.startGesture(const Offset(250, 300));
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();

    expect(find.textContaining('%'), findsOneWidget);

    await gesture.up();
  });

  testWidgets('locked overlay ignores drags entirely', (tester) async {
    final brightnessValues = <double>[];
    final volumeValues = <double>[];
    await pumpOverlay(
      tester,
      locked: true,
      onBrightnessChanged: brightnessValues.add,
      onVolumeChanged: volumeValues.add,
    );

    await tester.dragFrom(const Offset(50, 300), const Offset(0, -120));
    await tester.pump();
    await tester.dragFrom(const Offset(250, 300), const Offset(0, -120));
    await tester.pump();

    expect(brightnessValues, isEmpty);
    expect(volumeValues, isEmpty);
    expect(find.textContaining('%'), findsNothing);
  });
}
