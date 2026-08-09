import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_streaming_engine/platform_streaming_engine.dart';

void main() {
  testWidgets('renders an AndroidView with the streaming surface view type on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MaterialApp(home: AiroStreamingSurfaceView()),
      );

      final view = tester.widget<AndroidView>(find.byType(AndroidView));
      expect(view.viewType, AiroStreamingSurfaceView.viewType);
      expect(view.viewType, 'com.airo.player/streaming_surface');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('degrades to an empty box on non-Android platforms', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        const MaterialApp(home: AiroStreamingSurfaceView()),
      );

      expect(find.byType(AndroidView), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
