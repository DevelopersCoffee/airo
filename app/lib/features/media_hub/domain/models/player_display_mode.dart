/// Player display states for the hero player
enum PlayerDisplayMode {
  /// Default collapsed state (~65% height)
  collapsed,

  /// Expanded state (full viewport, not system fullscreen)
  expanded,

  /// System fullscreen mode
  fullscreen,

  /// Mini player bar only (when navigating away)
  mini,

  /// No player visible
  hidden;

  /// Check if player is in any visible state
  bool get isVisible => this != PlayerDisplayMode.hidden;

  /// Check if player is in full view (expanded or fullscreen)
  bool get isFullView =>
      this == PlayerDisplayMode.expanded ||
      this == PlayerDisplayMode.fullscreen;

  /// Check if player is minimized
  bool get isMinimized => this == PlayerDisplayMode.mini;
}
