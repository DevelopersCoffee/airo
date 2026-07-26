import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// issues/05-device-scaling-overscan.md acceptance criterion 1: no
// actionable content may cross the 32x24 logical-pixel overscan budget.
// This proves the shared primitive itself is correct at the required
// device-matrix logical sizes; it does not substitute for the physical
// device qualification pass the issue calls for separately.
void main() {
  test('constants match the design\'s 32x24 budget', () {
    expect(TvOverscanConstants.horizontalInset, 32.0);
    expect(TvOverscanConstants.verticalInset, 24.0);
    expect(
      TvOverscanConstants.padding,
      const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    );
  });

  for (final size in [
    const Size(960, 540),
    const Size(1280, 720),
    const Size(1920, 1080),
  ]) {
    testWidgets('insets content by exactly 32x24 at ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: TvOverscanSafeArea(
            child: ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(key: ValueKey('content')),
            ),
          ),
        ),
      );

      final contentRect = tester.getRect(find.byKey(const ValueKey('content')));

      expect(contentRect.left, TvOverscanConstants.horizontalInset);
      expect(contentRect.top, TvOverscanConstants.verticalInset);
      expect(
        size.width - contentRect.right,
        TvOverscanConstants.horizontalInset,
      );
      expect(
        size.height - contentRect.bottom,
        TvOverscanConstants.verticalInset,
      );
    });
  }
}
