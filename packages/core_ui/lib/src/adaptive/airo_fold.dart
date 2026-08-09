import 'dart:ui';

import 'package:flutter/widgets.dart';

/// How a foldable device's screen is currently folded.
enum FoldPosture {
  /// No hinge/fold reported, or the device is flat.
  none,

  /// Book-style: two halves at an angle, hinge usually vertical.
  halfOpened,

  /// Laptop-style: propped up with the hinge horizontal.
  tabletop,
}

/// Fold state for the current window, resolved from the platform's raw
/// [DisplayFeature] list.
class FoldInfo {
  const FoldInfo({required this.posture, required this.hingeBounds});

  static const none = FoldInfo(posture: FoldPosture.none, hingeBounds: null);

  final FoldPosture posture;

  /// The hinge's bounds in the same coordinate space as [MediaQuery]
  /// layout constraints, or null when there is no fold.
  final Rect? hingeBounds;
}

/// Foldable-device crease detection, built on Flutter's own
/// `MediaQuery.displayFeatures` — no extra package required.
///
/// See docs/ui/RESPONSIVE_STANDARDS.md, "Foldable / crease rule".
class AiroFold {
  AiroFold._();

  /// Resolves the current [FoldInfo] for [context]. Returns
  /// [FoldInfo.none] when the device reports no hinge, or reports one
  /// lying flat (`postureFlat` — fully unfolded, nothing to avoid) — the
  /// case for every non-foldable device, and the default in tests.
  static FoldInfo of(BuildContext context) {
    final features = MediaQuery.of(context).displayFeatures;
    for (final feature in features) {
      if (feature.type != DisplayFeatureType.hinge &&
          feature.type != DisplayFeatureType.fold) {
        continue;
      }
      if (feature.state != DisplayFeatureState.postureHalfOpened) continue;
      // Flutter's DisplayFeatureState only distinguishes flat vs.
      // half-opened; book (vertical hinge) vs. tabletop (horizontal hinge)
      // posture comes from the hinge's own orientation.
      final bounds = feature.bounds;
      final posture = bounds.height >= bounds.width
          ? FoldPosture.halfOpened
          : FoldPosture.tabletop;
      return FoldInfo(posture: posture, hingeBounds: bounds);
    }
    return FoldInfo.none;
  }

  /// Whether [contentBounds] would have the hinge running through it —
  /// i.e. the hinge overlaps the rect with room on both sides, rather than
  /// sitting at or outside an edge.
  static bool straddles(Rect contentBounds, FoldInfo fold) {
    final hinge = fold.hingeBounds;
    if (fold.posture == FoldPosture.none || hinge == null) return false;
    if (!hinge.overlaps(contentBounds)) return false;
    final hasRoomLeftOrAbove =
        hinge.left > contentBounds.left || hinge.top > contentBounds.top;
    final hasRoomRightOrBelow =
        hinge.right < contentBounds.right ||
        hinge.bottom < contentBounds.bottom;
    return hasRoomLeftOrAbove && hasRoomRightOrBelow;
  }
}
