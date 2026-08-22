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

/// A hybrid, deterministic extractor: high-precision patterns first, then a
/// capitalised-phrase catch-all. No ML model, no download, no `ModelPort`.
///
/// Scoping decision (issue #1463): a contextual NER model would route through
/// the local model via `ModelPort`. This pass stays rule-based so the
/// inspector always has typed entities without a loaded GGUF.
///
/// Specific shapes claim their span before the generic term pass, so
/// "Dr. Rao" is a person (not an orphaned "Rao"), "Optimist Corp." is an
/// organization, and "in Chicago" is a location rather than a bare term.
class RuleBasedEntityExtractor implements EntityExtractor {
  const RuleBasedEntityExtractor();

  static final RegExp _email = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );

  static final RegExp _identifier = RegExp(
    r'\b[A-Z]{2,}[-/][A-Z0-9]{2,}(?:[-/][A-Z0-9]+)*\b',
  );

  static final RegExp _phone = RegExp(
    r'(?:\+?\d{1,3}[\s.-])?(?:\(\d{3}\)|\d{3})[\s.-]\d{3}[\s.-]\d{4}\b',
  );

  static final RegExp _relativeDate = RegExp(
    r'\b(?:today|yesterday|tomorrow)\b',
    caseSensitive: false,
  );

  static final RegExp _productNamed = RegExp(
    r'\b(?:iPhone|iPad|iMac|MacBook|iPod|AirPods|Pixel|Galaxy|Kindle)'
    r'[A-Za-z0-9]*\b',
  );

  static final RegExp _productSuffixed = RegExp(
    r'\b[A-Z][A-Za-z0-9]+ (?:Cloud|Watch|Phone)\b',
  );

  static final RegExp _eventNamed = RegExp(
    r'\b(?:Olympic Games|FIFA World Cup|World War (?:[IVX]+|\d+))\b',
  );

  static final RegExp _eventSuffixed = RegExp(
    r'\b[A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)? '
    r'(?:Games|Conference|Festival|Cup|Summit)\b',
  );

  static final RegExp _money = RegExp(
    r'(?:\$|\b(?:USD|INR|EUR|GBP|Rs\.?)\b)\s*\d[\d,]*(?:\.\d+)?'
    r'(?:\s*(?:million|billion|thousand|hundred))?\b',
    caseSensitive: false,
  );

  static final RegExp _percent = RegExp(r'\b\d+(?:\.\d+)?%');

  static final RegExp _dayMonthDate = RegExp(
    r'\b\d{1,2}(?:st|nd|rd|th)?\s+'
    r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*'
    r'(?:\s*,?\s*\d{4})?\b',
    caseSensitive: false,
  );

  static final RegExp _monthDayDate = RegExp(
    r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\s+'
    r'\d{1,2}(?:st|nd|rd|th)?'
    r'(?:\s*,\s*\d{4}|\s+\d{4})?\b',
    caseSensitive: false,
  );

  static final RegExp _isoDate = RegExp(r'\b\d{4}-\d{2}-\d{2}\b');

  static final RegExp _honorific = RegExp(
    r'\b(?:(?:Dr|Mr|Mrs|Ms|Prof)\.|Sir)\s+[A-Z][A-Za-z]+'
    r'(?:\s+[A-Z][A-Za-z]+)?\b',
  );

  static final RegExp _titledPerson = RegExp(
    r'\b(?:CEO|CFO|CTO|COO|CMO|Founder|President|Director|'
    r'Chairman|Chairwoman|Professor|Judge)\s*,?\s+'
    r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b',
  );

  static final RegExp _organization = RegExp(
    r'\b[A-Z][A-Za-z0-9&]+(?:\s+[A-Z][A-Za-z0-9&]+){0,7}\s+'
    r'(?:(?:Corp|Inc|Ltd|LLC|LLP|PLC|GmbH|University|Hospital|'
    r'Foundation|Institute|Organization)\b\.?|Co\.)',
  );

  static final RegExp _location = RegExp(
    r'\b(?:in|at|from|near)\s+'
    r'([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+){0,2})\b',
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
    'Make',
    'Can',
    'Hi',
    'Give',
    'Hello',
    'On',
    'In',
    'At',
    'From',
    'Near',
  };

  static const Set<String> _roleTitles = {
    'CEO',
    'CFO',
    'CTO',
    'COO',
    'CMO',
    'Founder',
    'President',
    'Director',
    'Chairman',
    'Chairwoman',
    'Professor',
    'Judge',
  };

  static const Set<String> _notFamilyNames = {
    'Brace',
    'Plan',
    'Note',
    'Dose',
    'Round',
    'Street',
    'Drive',
    'Avenue',
    'City',
    'Games',
    'War',
    'Cup',
    'Cloud',
    'Phone',
    'Watch',
    'Conference',
    'Festival',
  };

  static const Set<String> _notGivenNames = {
    'New',
    'North',
    'South',
    'East',
    'West',
    'United',
    'National',
    'International',
    'Lake',
    'Mount',
    'San',
    'Los',
    'Las',
    'Saint',
    'Knee',
  };

  static const Set<String> _monthWords = {
    'Jan',
    'January',
    'Feb',
    'February',
    'Mar',
    'March',
    'Apr',
    'April',
    'May',
    'Jun',
    'June',
    'Jul',
    'July',
    'Aug',
    'August',
    'Sep',
    'Sept',
    'September',
    'Oct',
    'October',
    'Nov',
    'November',
    'Dec',
    'December',
  };

  @override
  List<ExtractedEntity> extract(String text) {
    if (text.trim().isEmpty) return const [];

    final claimed = <_Span>[];
    final positioned = <_Positioned>[];

    void take(Iterable<RegExpMatch> matches, EntityType type, {int group = 0}) {
      for (final match in matches) {
        final start = _groupStart(match, group);
        final end = start + match.group(group)!.length;
        final span = _Span(start, end);
        if (claimed.any(span.overlaps)) continue;
        claimed.add(span);
        positioned.add(
          _Positioned(
            start,
            ExtractedEntity(
              text: match.group(group)!,
              type: type,
              start: start,
              end: end,
            ),
          ),
        );
      }
    }

    // Most specific patterns claim first so the capitalised-phrase pass
    // never fragments "Dr. Rao", "$5 million", or "Optimist Corp.".
    take(_email.allMatches(text), EntityType.identifier);
    take(_phone.allMatches(text), EntityType.identifier);
    take(_identifier.allMatches(text), EntityType.identifier);
    take(_money.allMatches(text), EntityType.money);
    take(_percent.allMatches(text), EntityType.money);
    take(_isoDate.allMatches(text), EntityType.date);
    take(_dayMonthDate.allMatches(text), EntityType.date);
    take(_monthDayDate.allMatches(text), EntityType.date);
    take(_relativeDate.allMatches(text), EntityType.date);
    take(_honorific.allMatches(text), EntityType.person);
    take(_titledPerson.allMatches(text), EntityType.person, group: 1);
    take(_organization.allMatches(text), EntityType.organization);
    take(_productNamed.allMatches(text), EntityType.product);
    take(_productSuffixed.allMatches(text), EntityType.product);
    take(_eventNamed.allMatches(text), EntityType.event);
    take(_eventSuffixed.allMatches(text), EntityType.event);
    _takeLocations(text, claimed, positioned);
    _takeCapitalisedPhrases(text, claimed, positioned);

    positioned.sort((a, b) => a.start.compareTo(b.start));

    final seen = <ExtractedEntity>{};
    final ordered = <ExtractedEntity>[];
    for (final item in positioned) {
      if (seen.add(item.entity)) ordered.add(item.entity);
    }
    return List.unmodifiable(ordered);
  }

  void _takeLocations(
    String text,
    List<_Span> claimed,
    List<_Positioned> positioned,
  ) {
    for (final match in _location.allMatches(text)) {
      final mention = match.group(1)!;
      final start = _groupStart(match, 1);
      final end = start + mention.length;
      final span = _Span(start, end);
      if (claimed.any(span.overlaps)) continue;
      final firstWord = mention.split(RegExp(r'\s+')).first;
      // Months and sentence-starters after in/at/from/near are not places.
      // Do not claim the span: "in The Ibuprofen" must still yield the term.
      if (_monthWords.contains(mention) ||
          _leadingStopwords.contains(firstWord)) {
        continue;
      }
      claimed.add(span);
      positioned.add(
        _Positioned(
          start,
          ExtractedEntity(
            text: mention,
            type: EntityType.location,
            start: start,
            end: end,
          ),
        ),
      );
    }
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

      final phrase = text.substring(token.start, end);
      if (_monthWords.contains(phrase)) {
        i = j;
        continue;
      }

      final type = _roleTitles.contains(phrase)
          ? EntityType.title
          : _isUntitledPerson(phrase)
          ? EntityType.person
          : EntityType.term;

      final phraseSpan = _Span(token.start, end);
      claimed.add(phraseSpan);
      positioned.add(
        _Positioned(
          token.start,
          ExtractedEntity(
            text: phrase,
            type: type,
            start: token.start,
            end: end,
          ),
        ),
      );
      i = j;
    }
  }

  static final RegExp _nameWord = RegExp(r'^[A-Z][a-z]{2,}$');

  static bool _isUntitledPerson(String phrase) {
    final parts = phrase.split(RegExp(r'\s+'));
    if (parts.length != 2) return false;
    if (!_nameWord.hasMatch(parts[0]) || !_nameWord.hasMatch(parts[1])) {
      return false;
    }
    if (_notGivenNames.contains(parts[0])) return false;
    if (_notFamilyNames.contains(parts[1])) return false;
    if (_leadingStopwords.contains(parts[0])) return false;
    if (_monthWords.contains(parts[0]) || _monthWords.contains(parts[1])) {
      return false;
    }
    return true;
  }
}

int _groupStart(RegExpMatch match, int group) {
  if (group == 0) return match.start;
  final part = match.group(group);
  final full = match.group(0);
  if (part == null || part.isEmpty || full == null) return match.start;
  final offset = full.lastIndexOf(part);
  if (offset < 0) return match.start;
  return match.start + offset;
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
