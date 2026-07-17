import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extension slot for the Playback Settings screen. Defaults to empty in the
/// public app — the airo-pro overlay overrides this provider (via
/// `ProviderScope.overrides` at bootstrap) to inject pro-only sections (e.g.
/// Picture-in-Picture) without editing this public screen directly, so
/// upstream syncs never conflict here.
final playbackSettingsExtraSectionsProvider = Provider<List<Widget>>(
  (ref) => const [],
);
