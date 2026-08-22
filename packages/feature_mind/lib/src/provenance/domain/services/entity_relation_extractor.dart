import '../models/entity_relation.dart';
import '../models/extracted_entity.dart';
import 'entity_extractor.dart';

/// Infers typed relations among entities already found in one text.
///
/// On-device and deterministic: no model, no network. High-precision type
/// pairs only — it does not emit a full clique of "mentioned with".
class EntityRelationExtractor {
  const EntityRelationExtractor({
    this.entities = const RuleBasedEntityExtractor(),
  });

  final EntityExtractor entities;

  /// Window in UTF-16 units for "near each other in the same clause".
  static const int nearWindow = 96;

  static final RegExp _titleCue = RegExp(
    r'\b(?:CEO|CFO|CTO|COO|CMO|Founder|President|Director|'
    r'Dr|Mr|Mrs|Ms|Prof)\b\.?',
    caseSensitive: false,
  );

  static final RegExp _announceCue = RegExp(
    r'\b(?:announc\w*|filed|dated|reported)\b',
    caseSensitive: false,
  );

  EntityRelationGraph extract(String text) {
    if (text.trim().isEmpty) return EntityRelationGraph.empty;
    return extractFrom(text, entities.extract(text));
  }

  EntityRelationGraph extractFrom(String text, List<ExtractedEntity> found) {
    if (found.isEmpty) {
      return EntityRelationGraph(entities: found);
    }

    final people = found.where((e) => e.type == EntityType.person);
    final orgs = found.where((e) => e.type == EntityType.organization);
    final locations = found.where((e) => e.type == EntityType.location);
    final dates = found.where((e) => e.type == EntityType.date);
    final money = found.where((e) => e.type == EntityType.money);

    final relations = <EntityRelation>{};
    final hasTitle = _titleCue.hasMatch(text);
    final announced = _announceCue.hasMatch(text);

    for (final org in orgs) {
      for (final person in people) {
        if (hasTitle || _near(person, org)) {
          relations.add(
            EntityRelation(
              from: person,
              kind: EntityRelationKind.worksAt,
              to: org,
            ),
          );
        }
      }
      for (final location in locations) {
        relations.add(
          EntityRelation(
            from: org,
            kind: EntityRelationKind.locatedIn,
            to: location,
          ),
        );
      }
      if (announced) {
        for (final date in dates) {
          relations.add(
            EntityRelation(
              from: org,
              kind: EntityRelationKind.announcedOn,
              to: date,
            ),
          );
        }
      }
      for (final amount in money) {
        relations.add(
          EntityRelation(
            from: org,
            kind: EntityRelationKind.valuedAt,
            to: amount,
          ),
        );
      }
    }

    final ordered = relations.toList(growable: false)
      ..sort((a, b) {
        final from = a.from.start.compareTo(b.from.start);
        if (from != 0) return from;
        return a.kind.index.compareTo(b.kind.index);
      });

    return EntityRelationGraph(
      entities: found,
      relations: List.unmodifiable(ordered),
    );
  }

  static bool _near(ExtractedEntity a, ExtractedEntity b) {
    if (a.end <= a.start || b.end <= b.start) return true;
    final gap = a.start <= b.start ? b.start - a.end : a.start - b.end;
    return gap <= nearWindow;
  }
}
