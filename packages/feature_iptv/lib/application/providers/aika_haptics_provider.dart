import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../aika_haptics.dart';

final aikaHapticsProvider = Provider<AikaHaptics>((ref) {
  final haptics = EngineAikaHaptics();
  ref.onDispose(() {
    unawaited(haptics.detachCastSession());
    unawaited(haptics.detachLocalPlayback());
  });
  return haptics;
});
