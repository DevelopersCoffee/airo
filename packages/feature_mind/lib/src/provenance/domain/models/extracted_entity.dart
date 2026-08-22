import 'package:flutter/foundation.dart';

/// The closed set of entity types the extractor can name.
///
/// A closed set rather than a free-form string for the same reason
/// [MindOpKind] is one: a new type must be a deliberate change to what the
/// inspector can render, not a typo that shows up unstyled.
enum EntityType {
  person,
  date,
  term,
  organization,
  location,
  money,
  identifier,
  document,
  product,
  event,
  title,
}

/// One entity pulled out of an op's title and detail text.
///
/// [text] is the verbatim substring that was matched — not normalised,
/// not title-cased — so a citation search against [ProjectionPort.search]
/// can find the same text back in the op it came from.
///
/// [start] and [end] are UTF-16 offsets in that source text. They are
/// omitted from equality so two mentions of the same typed string still
/// collapse in the inspector list.
@immutable
class ExtractedEntity {
  const ExtractedEntity({
    required this.text,
    required this.type,
    this.start = 0,
    this.end = 0,
  });

  final String text;
  final EntityType type;
  final int start;
  final int end;

  Map<String, Object> toJson() => {
    'text': text,
    'type': type.name,
    if (end > start) 'start': start,
    if (end > start) 'end': end,
  };

  @override
  bool operator ==(Object other) =>
      other is ExtractedEntity && other.text == text && other.type == type;

  @override
  int get hashCode => Object.hash(text, type);

  @override
  String toString() => 'ExtractedEntity(${type.name}, "$text")';
}

/// Structured views of an extraction pass (lists, JSON, grouped types).
extension ExtractedEntityList on List<ExtractedEntity> {
  /// Groups verbatim mentions under their type name, preserving first-seen
  /// order inside each type.
  Map<String, List<String>> toStructuredMap() {
    final grouped = <String, List<String>>{};
    for (final entity in this) {
      grouped.putIfAbsent(entity.type.name, () => <String>[]).add(entity.text);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    });
  }

  List<Map<String, Object>> toJson() => [
    for (final entity in this) entity.toJson(),
  ];
}
