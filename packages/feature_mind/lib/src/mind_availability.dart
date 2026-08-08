/// Whether this build carries Airo Mind. Real answer: yes.
///
/// Mirrors `AiroMindAbsent` in `packages/stubs/feature_mind_stub`, which
/// answers `true`. Both variants export a symbol with this exact name and
/// shape so a caller can reference it unconditionally regardless of which one
/// `pubspec_overrides.yaml` resolves to -- Dart has no conditional import on
/// "which package a name resolved to", only on `dart.library.*` and
/// environment defines, neither of which fits a dependency-override swap.
///
/// `R05`: a shared-surface build (web, TV) must not offer a Mind destination.
/// The product shell reads this rather than the module registry's contents,
/// because a shell that reaches for `MindModule` when the stub is in place
/// gets a compile error -- the stub deliberately exports no such class -- and
/// this constant is what lets the shell avoid that reference in the first
/// place.
abstract final class AiroMindAbsent {
  static const bool value = false;
}
