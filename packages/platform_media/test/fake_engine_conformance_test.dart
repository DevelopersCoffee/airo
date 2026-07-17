import 'package:platform_player/platform_player.dart';

import 'support/airo_playback_engine_conformance.dart';

void main() {
  runAiroPlaybackEngineConformanceSuite('fake', () => FakeAiroPlaybackEngine());
}
