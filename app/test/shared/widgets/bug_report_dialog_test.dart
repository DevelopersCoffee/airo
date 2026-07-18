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
}
