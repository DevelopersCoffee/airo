/// Selectable MultiView arrangements. Eight kinds, all within
/// [kAiroMultiviewHardCap] sessions — the mosaic library the Cast remote
/// and local stage share, including the PiP-style [spotlight] (one large
/// tile + three stacked) the previous 1/2/3/4 count-only layouts lacked.
enum MultiviewLayoutKind {
  single(1),
  splitHorizontal(2),
  splitVertical(2),
  tripleTop(3),
  tripleBottom(3),
  tripleLeft(3),
  quad(4),
  spotlight(4);

  const MultiviewLayoutKind(this.tileCount);

  /// How many tiles this arrangement shows. Empty placeholders fill any
  /// unused cells; a live session is never hidden to satisfy a smaller
  /// layout — see [resolveMultiviewLayout].
  final int tileCount;

  /// Wire name on the Cast MultiView protocol (`multiview.set_layout` /
  /// `multiview.state.layout`). Stable; do not rename without a protocol
  /// version bump.
  String get wireName => name;

  static MultiviewLayoutKind? tryParse(String? raw) {
    if (raw == null) return null;
    for (final kind in values) {
      if (kind.wireName == raw) return kind;
    }
    return null;
  }

  /// Count-derived default matching the layouts [MultiviewStage] used
  /// before a picker existed: 1 → single, 2 → side-by-side, 3 → two-over-one,
  /// 4+ → 2×2.
  static MultiviewLayoutKind defaultForCount(int sessionCount) {
    final count = sessionCount < 1 ? 1 : sessionCount;
    return switch (count) {
      1 => single,
      2 => splitHorizontal,
      3 => tripleBottom,
      _ => quad,
    };
  }
}

/// Picks the arrangement actually rendered. A preferred layout is kept
/// when it has room for every live session (empty cells fill the rest);
/// otherwise we fall back so a playing stream is never dropped off-screen.
MultiviewLayoutKind resolveMultiviewLayout({
  required MultiviewLayoutKind? preferred,
  required int sessionCount,
}) {
  if (preferred != null &&
      (sessionCount <= 0 || preferred.tileCount >= sessionCount)) {
    return preferred;
  }
  return MultiviewLayoutKind.defaultForCount(sessionCount);
}
