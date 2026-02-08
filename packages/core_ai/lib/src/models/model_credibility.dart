/// Model credibility/trust levels.
///
/// Indicates the source and trustworthiness of an offline LLM model.
/// Used to help users make informed decisions about model safety.
enum ModelCredibility {
  /// Official model from the original vendor (Google, Meta, Microsoft, etc.).
  /// Highest trust level - verified source and signed artifacts.
  official('Official', 'From original vendor', trustScore: 100, icon: '✓'),

  /// Verified model from a trusted third-party source.
  /// High trust - has been reviewed and verified by the community.
  verified('Verified', 'Community verified', trustScore: 80, icon: '◉'),

  /// Popular community model with good reputation.
  /// Medium-high trust - widely used and tested.
  popular('Popular', 'Widely used', trustScore: 60, icon: '★'),

  /// Community-contributed model without verification.
  /// Medium trust - use with caution.
  community('Community', 'Community contributed', trustScore: 40, icon: '○'),

  /// Unverified model from unknown source.
  /// Low trust - not recommended for sensitive data.
  unverified('Unverified', 'Unknown source', trustScore: 20, icon: '⚠'),

  /// User's own custom/fine-tuned model.
  /// Trust depends on user's own assessment.
  custom('Custom', 'User provided', trustScore: 50, icon: '◇');

  const ModelCredibility(
    this.displayName,
    this.description, {
    required this.trustScore,
    required this.icon,
  });

  /// Human-readable name for display.
  final String displayName;

  /// Brief description of the credibility level.
  final String description;

  /// Trust score from 0-100.
  /// Higher = more trustworthy.
  final int trustScore;

  /// Icon character for UI display.
  final String icon;

  /// Returns true if this is a trusted source (official or verified).
  bool get isTrusted => this == official || this == verified;

  /// Returns true if the user should be warned about using this model.
  bool get shouldWarn => this == unverified;

  /// Returns true if this model should be shown with a trust badge.
  bool get showBadge => this == official || this == verified;

  /// Get a color suggestion for UI display.
  /// Returns a hex color string suitable for the trust level.
  String get colorHex => switch (this) {
    official => '#4CAF50', // Green
    verified => '#2196F3', // Blue
    popular => '#9C27B0', // Purple
    community => '#FF9800', // Orange
    unverified => '#F44336', // Red
    custom => '#607D8B', // Blue Grey
  };

  /// Get detailed trust information for display.
  String get trustInfo => switch (this) {
    official =>
      'This model is from the original vendor and has been '
          'cryptographically signed. Safe to use with sensitive data.',
    verified =>
      'This model has been reviewed and verified by the community. '
          'Generally safe to use.',
    popular =>
      'This model is widely used by the community with a good '
          'track record. Exercise normal caution.',
    community =>
      'This model is contributed by the community without formal '
          'verification. Use with caution.',
    unverified =>
      'This model is from an unknown source and has not been '
          'verified. Not recommended for sensitive data.',
    custom =>
      'This is your own custom model. Trust level depends on your '
          'own assessment of the source.',
  };
}
