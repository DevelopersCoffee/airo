import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Receiver video surface for the Wave A proof-of-concept (SPEC.md
/// AD-1/AD-5, Phase 2). Hosts the native `SurfaceView` registered as
/// [viewType] by `AiroStreamingSurfaceViewFactory` on the Kotlin side.
///
/// Android-only for now — degrades to an empty box everywhere else rather
/// than throwing, matching every other native seam in this codebase
/// (`AiroNativePictureInPicture`, `AiroStreamingEngineChannel`).
class AiroStreamingSurfaceView extends StatelessWidget {
  const AiroStreamingSurfaceView({super.key});

  static const String viewType = 'com.airo.player/streaming_surface';

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return const AndroidView(viewType: viewType);
  }
}
