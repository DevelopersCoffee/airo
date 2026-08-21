enum SourceClass { primary, secondary, tertiary, unknown }

enum SourceKind {
  official,
  academic,
  government,
  standard,
  news,
  technical,
  community,
  social,
  seo,
  unknown,
}

class SourceClassification {
  const SourceClassification({required this.sourceClass, required this.kind});

  final SourceClass sourceClass;
  final SourceKind kind;

  @override
  bool operator ==(Object other) =>
      other is SourceClassification &&
      other.sourceClass == sourceClass &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(sourceClass, kind);
}

SourceClassification classifySourceUrl(String url) {
  final lower = url.toLowerCase();
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (lower.contains('arxiv.org') || lower.contains('doi.org')) {
    return const SourceClassification(
      sourceClass: SourceClass.primary,
      kind: SourceKind.academic,
    );
  }
  if (lower.contains('wikipedia.org')) {
    return const SourceClassification(
      sourceClass: SourceClass.tertiary,
      kind: SourceKind.community,
    );
  }
  if (host.endsWith('.gov') || host.contains('.gov.')) {
    return const SourceClassification(
      sourceClass: SourceClass.primary,
      kind: SourceKind.government,
    );
  }
  if (host.contains('github.com')) {
    return const SourceClassification(
      sourceClass: SourceClass.primary,
      kind: SourceKind.technical,
    );
  }
  return const SourceClassification(
    sourceClass: SourceClass.unknown,
    kind: SourceKind.unknown,
  );
}
