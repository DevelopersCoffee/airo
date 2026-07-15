import 'package:feature_iptv/presentation/tv/iptv_tv.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TvFocusable supports cursor hover focus and mouse selection', (
    tester,
  ) async {
    var focusCount = 0;
    var selectCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 80,
              child: TvFocusable(
                onFocus: () => focusCount += 1,
                onSelect: () => selectCount += 1,
                semanticLabel: 'Play channel',
                child: const Center(child: Text('Play')),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: Offset.zero);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Play')));
    await tester.pumpAndSettle();

    expect(focusCount, 1);
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.tap(find.text('Play'), kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(selectCount, 1);
  });
}
