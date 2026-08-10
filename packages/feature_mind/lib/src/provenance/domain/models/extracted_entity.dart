import 'package:flutter/foundation.dart';

/// The closed set of entity types the v1 extractor can name.
///
/// A closed set rather than a free-form string for the same reason
/// [MindOpKind] is one: a new type must be a deliberate change to what the
/// inspector can render, not a typo that shows up unstyled.
enum EntityType { person, date, term }

/// One entity pulled out of an op's title and detail text.
///
/// [text] is the verbatim substring that was matched — not normalised,
/// not title-cased — so a citation search against [ProjectionPort.search]
/// can find the same text back in the op it came from.
@immutable
class ExtractedEntity {
  const ExtractedEntity({required this.text, required this.type});

  final String text;
  final EntityType type;

  @override
  bool operator ==(Object other) =>
      other is ExtractedEntity && other.text == text && other.type == type;

  @override
  int get hashCode => Object.hash(text, type);

  @override
  String toString() => 'ExtractedEntity(${type.name}, "$text")';
}
