import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../runtime/fixture/fixture_mind_runtime.dart';
import '../../runtime/mind_runtime.dart';

/// The [MindRuntime] Audio Scribe (and, as they land, other assistant
/// surfaces) writes operations against.
///
/// Defaults to [FixtureMindRuntime]: `RustMindRuntime.log` is not implemented
/// yet (#1213, #1214, #1215), so a screen built against the real runtime
/// today would throw [MindPortUnavailable] on every append. The fixture
/// behaves like the real port — appending really does advance the sequence —
/// so the consent gate and its timeline entry are exercised end to end while
/// the Rust log lands. Overridden with a test double in widget tests, and
/// intended to be overridden with [RustMindRuntime] once the log port ships.
final mindRuntimeProvider = Provider<MindRuntime>(
  (ref) => FixtureMindRuntime(),
);
