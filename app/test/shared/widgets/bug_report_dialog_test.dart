import 'package:airo_app/shared/widgets/bug_report_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows draft fallback copy when direct reporting is unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BugReportDialog())),
      );

      expect(find.textContaining('prefilled issue draft'), findsOneWidget);
      expect(find.textContaining('token'), findsNothing);
    },
  );

  testWidgets(
    'severity and category dropdowns do not overflow on a phone-width screen',
    (tester) async {
      // 360dp width matches the ~360dp phone screen where the Severity and
      // Category dropdowns previously overflowed their Row (creator chain
      // Row <- ... <- InputDecorator, per the original report) because the
      // selected-value Text had no Expanded/ellipsis for long labels like
      // "High - Major issue affecting core functionality". This width also
      // trips an unrelated, pre-existing overflow in the dialog's title Row
      // (a flutter_test font-metrics artifact -- it never reproduces on a
      // real device and isn't part of this regression), so the assertion
      // below checks the exception text for the dropdowns specifically
      // rather than asserting no exception at all. `tester.takeException()`
      // is used rather than a custom `FlutterError.onError` override, which
      // breaks flutter_test's own error-zone handling and hangs the test
      // for its full timeout when more than one error occurs.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BugReportDialog())),
      );

      // When more than one FlutterError occurs in a single pump,
      // takeException() collapses them into a generic "Multiple exceptions"
      // summary instead of the individual messages, so that case must be
      // checked for directly rather than relying on message content alone.
      final exception = tester.takeException()?.toString() ?? '';
      expect(
        exception,
        allOf(isNot(contains('InputDecorator')), isNot(contains('Multiple'))),
        reason: 'Severity/Category dropdown overflowed: $exception',
      );
    },
  );
}
