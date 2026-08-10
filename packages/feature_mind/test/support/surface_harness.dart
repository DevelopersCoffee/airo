import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone surface class from the design: 390 × 844, 48 px minimum target.
const Size kMindPhoneSize = Size(390, 844);

/// Pumps [surface] at the design's phone size.
///
/// Every phone surface test uses this rather than the default 800 × 600, which
/// is not a phone and would let a layout pass that overflows on the real one.
Future<void> pumpSurface(WidgetTester tester, Widget surface) async {
  tester.view.physicalSize = kMindPhoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: kMindPhoneSize),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: surface),
        ),
      ),
    ),
  );
  await tester.pump();
}
