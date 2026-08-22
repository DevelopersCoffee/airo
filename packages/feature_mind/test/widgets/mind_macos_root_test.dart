import 'package:feature_mind/src/assistant/consent/mind_runtime_provider.dart';
import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/widgets/mind_command_palette_scope.dart';
import 'package:feature_mind/src/widgets/mind_macos_root.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'macOS chrome builds without MaterialApp introducing Directionality',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mindRuntimeProvider.overrideWithValue(FixtureMindRuntime()),
            ],
            child: const MindMacOsRoot(child: SizedBox.shrink()),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(MindCommandPaletteScope), findsOneWidget);
        expect(find.byType(Directionality), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
