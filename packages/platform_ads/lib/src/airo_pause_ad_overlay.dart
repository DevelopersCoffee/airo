import 'package:flutter/material.dart';

import 'aika_ad_policy.dart';
import 'aika_native_ad_card.dart';

/// Pause Ad overlay widget for video player viewports.
///
/// When [isPaused] is true, displays a non-intrusive high-res pause ad card
/// without stopping audio or stream session state.
class AiroPauseAdOverlay extends StatelessWidget {
  const AiroPauseAdOverlay({
    required this.isPaused,
    super.key,
    this.child,
    this.isLeanback = false,
    this.isCasting = false,
    this.onDismiss,
  });

  final bool isPaused;
  final Widget? child;
  final bool isLeanback;
  final bool isCasting;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ignore: use_null_aware_elements
        if (child != null) child!,
        if (isPaused)
          Positioned(
            bottom: 16,
            right: 16,
            left: 16,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AikaNativeAdCard(
                  placement: AikaAdPlacement.pause,
                  isLeanback: isLeanback,
                  isCasting: isCasting,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
