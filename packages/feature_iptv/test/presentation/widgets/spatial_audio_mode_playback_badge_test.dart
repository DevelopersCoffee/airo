import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/spatial_audio_mode_provider.dart';
import 'package:feature_iptv/presentation/widgets/spatial_audio_mode_playback_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows Original label by default', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(body: SpatialAudioModePlaybackBadge()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Audio: Original'), findsOneWidget);
    expect(find.text('Direct decode'), findsOneWidget);
  });

  testWidgets('shows Spatial label when preference is spatial', (tester) async {
    SharedPreferences.setMockInitialValues({
      SpatialAudioModeNotifier.storageKey: 'spatial',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(body: SpatialAudioModePlaybackBadge()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Audio: Spatial (experimental)'), findsOneWidget);
    expect(find.text('Post-decode PCM (passthrough)'), findsOneWidget);
  });
}
