/// How much local LLM inference this device can safely sustain.
///
/// Four tiers, not a continuous score: `TaskModelRouter`/`ModelCatalog`
/// filter installed models by `OfflineModelInfo.parameterCount`, and every
/// threshold this module produces needs a stable name a routing-decision log
/// can print -- a float invites drift between "what the policy computed" and
/// "what the log shows a person."
///
/// #1631 (MIND-LLM-4). `large` is still bounded by the milestone's non-goal
/// of shipping no 7B+ models -- `ModelCatalog` never offers anything this
/// tier could not run, so [maxParameterCount] is a safety ceiling, not a
/// promise that a model that large exists in the catalog.
enum LlmDeviceTier {
  /// Skip local inference entirely. Every request routes to cloud (with
  /// explicit consent) or is refused.
  none,

  /// Up to a 1B-parameter model.
  small,

  /// Up to a 3B-parameter model.
  medium,

  /// Larger than 3B, up to the milestone's 7B ceiling.
  large;

  /// Upper bound on installed-model parameter count this tier may load
  /// locally. Null for [none] -- there is no local budget to bound.
  int? get maxParameterCount => switch (this) {
    LlmDeviceTier.none => null,
    LlmDeviceTier.small => 1000000000,
    LlmDeviceTier.medium => 3000000000,
    LlmDeviceTier.large => 7000000000,
  };

  bool get supportsLocalInference => this != LlmDeviceTier.none;

  /// Stable identifier for logs and diagnostics -- never the enum's `name`
  /// directly, so a Dart rename cannot silently change a logged value.
  String get stableId => switch (this) {
    LlmDeviceTier.none => 'none',
    LlmDeviceTier.small => 'small',
    LlmDeviceTier.medium => 'medium',
    LlmDeviceTier.large => 'large',
  };
}
