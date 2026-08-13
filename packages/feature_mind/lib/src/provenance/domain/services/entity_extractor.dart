import '../models/extracted_entity.dart';

/// On-device entity extraction over an op's text.
///
/// "On-device" is load-bearing (issue #1463): no implementation of this
/// interface may call a network endpoint, and a caller that wraps a remote
/// model behind it has broken the contract the inspector's copy makes to the
/// person reading it.
abstract interface class EntityExtractor {
  /// Returns typed entities found in [text], in the order they appear.
  ///
  /// An empty list means "ran and found nothing" — [EntityExtractionUnavailable]
  /// is thrown instead when extraction could not run at all, because those
  /// two outcomes must never render the same way in the inspector.
  List<ExtractedEntity> extract(String text);
}

/// Thrown when no extraction capability exists on this device.
///
/// [RuleBasedEntityExtractor] never throws this — the regex pass has no
/// external dependency — but a future model-backed extractor (routed through
/// `ModelPort`, see the scoping note on issue #1463) can, when no model is
/// loaded.
class EntityExtractionUnavailable implements Exception {
  const EntityExtractionUnavailable([
    this.reason = 'Entity extraction is unavailable on this device.',
  ]);

  final String reason;

  @override
  String toString() => reason;
}

/// A lightweight, deterministic v1 extractor: no ML model, no download, no
/// `ModelPort` dependency.
///
/// Scoping decision (issue #1463): a proper NER pass would route through the
/// local model via `ModelPort`, but `core_ai` and `feature_mind/src/llama`
/// carry no entity-extraction capability today, and training one is out of
/// scope for this issue. This pass recognises three shapes — `Honorific.
/// Name` as a person, `DD Mon` as a date, and a run of capitalised words as
/// a generic term — which reproduces the design's own worked example ("Dr.
/// Rao, Ibuprofen, 14 Aug, Brace" from a discharge note) and gives the
/// inspector real, typed entities to render.
///
/// Known limitation, accepted for v1: there is no grammar model behind this,
/// so a proper noun that opens a sentence and is not one of the small set of
/// curated [_leadingStopwords] still extracts as a term. A false positive of
/// that shape is the accepted cost of not shipping a full NER model for one
/// P1 issue; the on-device model-backed extractor that replaces this one can
/// remove it.
class RuleBasedEntityExtractor implements EntityExtractor {
  const RuleBasedEntityExtractor();

  static final RegExp _honorific = RegExp(
    r'\b(?:Dr|Mr|Mrs|Ms|Prof)\.\s+[A-Z][A-Za-z]*\b',
  );

  static final RegExp _date = RegExp(
    r'\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)'
    r'[a-z]*\b',
    caseSensitive: false,
  );

  static final RegExp _word = RegExp(r'[A-Za-z]+');

  static final RegExp _capitalisedWord = RegExp(r'^[A-Z][a-zA-Z]{2,}$');

  /// Ordinary sentence-starters that must never read as an entity on their
  /// own, so "The Ibuprofen dose…" extracts "Ibuprofen" and not "The".
  static const Set<String> _leadingStopwords = {
    'The',
    'This',
    'That',
    'It',
    'A',
    'An',
    'He',
    'She',
    'They',
    'We',
    'I',
    'Follow',
    'Please',
    'There',
  };

  @override
  List<ExtractedEntity> extract(String text) {
    if (text.trim().isEmpty) return const [];

    final claimed = <_Span>[];
    final positioned = <_Positioned>[];

    void take(Iterable<RegExpMatch> matches, EntityType type) {
      for (final match in matches) {
        final span = _Span(match.start, match.end);
        if (claimed.any(span.overlaps)) continue;
        claimed.add(span);
        positioned.add(
          _Positioned(
            match.start,
            ExtractedEntity(text: match.group(0)!, type: type),
          ),
        );
      }
    }

    // Order matters: honorific and date shapes are the most specific and
    // claim their span first, so the generic term pass below never
    // fragments "Dr. Rao" into an orphaned "Rao".
    take(_honorific.allMatches(text), EntityType.person);
    take(_date.allMatches(text), EntityType.date);

    _takeCapitalisedPhrases(text, claimed, positioned);

    positioned.sort((a, b) => a.start.compareTo(b.start));

    final seen = <ExtractedEntity>{};
    final ordered = <ExtractedEntity>[];
    for (final item in positioned) {
      if (seen.add(item.entity)) ordered.add(item.entity);
    }
    return List.unmodifiable(ordered);
  }

  /// Merges runs of adjacent capitalised words — separated by nothing but
  /// whitespace, so punctuation always breaks a run — into one phrase entity
  /// ("Knee Brace"), skipping any run whose first word is an ordinary
  /// sentence-starter.
  void _takeCapitalisedPhrases(
    String text,
    List<_Span> claimed,
    List<_Positioned> positioned,
  ) {
    final tokens = _word.allMatches(text).toList(growable: false);

    var i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      final word = token.group(0)!;
      final span = _Span(token.start, token.end);

      final isEntityStart =
          _capitalisedWord.hasMatch(word) &&
          !_leadingStopwords.contains(word) &&
          !claimed.any(span.overlaps);

      if (!isEntityStart) {
        i++;
        continue;
      }

      var end = token.end;
      var j = i + 1;
      while (j < tokens.length) {
        final next = tokens[j];
        final between = text.substring(end, next.start);
        final nextWord = next.group(0)!;
        final nextSpan = _Span(next.start, next.end);
        final isContiguousEntity =
            between.trim().isEmpty &&
            _capitalisedWord.hasMatch(nextWord) &&
            !claimed.any(nextSpan.overlaps);
        if (!isContiguousEntity) break;
        end = next.end;
        j++;
      }

      final phraseSpan = _Span(token.start, end);
      claimed.add(phraseSpan);
      positioned.add(
        _Positioned(
          token.start,
          ExtractedEntity(
            text: text.substring(token.start, end),
            type: EntityType.term,
          ),
        ),
      );
      i = j;
    }
  }
}

class _Span {
  const _Span(this.start, this.end);

  final int start;
  final int end;

  bool overlaps(_Span other) => start < other.end && other.start < end;
}

class _Positioned {
  const _Positioned(this.start, this.entity);

  final int start;
  final ExtractedEntity entity;
}
