import 'dart:convert';

import '../../../runtime/models/model_models.dart';
import '../../../runtime/ports/model_port.dart';
import '../models/extracted_entity.dart';
import 'entity_extractor.dart';

/// Completes a GBNF-constrained prompt on a locally loaded GGUF.
///
/// Production wires this to the on-device generation bridge. Tests inject a
/// scripted completion. The callback must not hit the network.
typedef NerComplete =
    Future<String> Function({required String prompt, required String grammar});

/// GGUF-backed NER. Throws [EntityExtractionUnavailable] when [ModelPort]
/// has no loaded model — distinct from "ran and found nothing".
///
/// On-device only (issue #1846 / #1463): the completion is a local GGUF
/// pass, never a remote endpoint.
class ModelBackedEntityExtractor {
  const ModelBackedEntityExtractor({
    required this.models,
    required this.complete,
  });

  final ModelPort models;
  final NerComplete complete;

  /// llama.cpp GBNF for a JSON array of `{text, type}` objects.
  static const grammar =
      'root ::= "[" ws (entity ("," ws entity)*)? ws "]"\n'
      r'entity ::= "{" ws "\"text\"" ws ":" ws string ws "," ws "\"type\"" ws ":" ws type ws "}"'
      '\n'
      'type ::= '
      r'"\"person\"" | "\"organization\"" | "\"location\"" | "\"date\"" | '
      r'"\"money\"" | "\"identifier\"" | "\"product\"" | "\"event\"" | '
      r'"\"title\"" | "\"term\"" | "\"document\""'
      '\n'
      r'string ::= "\"" chars "\""'
      '\n'
      r'chars ::= char*'
      '\n'
      r'char ::= [^"\\] | "\\" ["\\/bfnrt]'
      '\n'
      r'ws ::= [ \t\n]*'
      '\n';

  Future<List<ExtractedEntity>> extract(String text) async {
    if (text.trim().isEmpty) return const [];
    if (!await _hasLoadedModel()) {
      throw const EntityExtractionUnavailable('no model loaded');
    }
    final raw = await complete(prompt: promptFor(text), grammar: grammar);
    return parseModelNerJson(raw, text);
  }

  Future<bool> _hasLoadedModel() async {
    final catalog = await models.all();
    return catalog.any((model) => model.residency == ModelResidency.loaded);
  }

  static String promptFor(String text) =>
      'Extract named entities from the text. Return a JSON array of objects '
      'with keys "text" and "type". Copy each entity\'s text verbatim from '
      'the source. Allowed types: person, organization, location, date, '
      'money, identifier, product, event, title, term, document.\n'
      'Text:\n<<<\n$text\n>>>\n';
}

/// Rules first, then a loaded GGUF pass for lowercase, Indic, and ambiguous
/// mentions. High-precision rule types (money, date, identifier) win on
/// overlap. Missing a model is not a failure — the rule list is returned.
class HybridEntityExtractor {
  const HybridEntityExtractor({
    this.rules = const RuleBasedEntityExtractor(),
    required this.model,
  });

  final EntityExtractor rules;
  final ModelBackedEntityExtractor model;

  Future<List<ExtractedEntity>> extract(String text) async {
    final ruleHits = rules.extract(text);
    List<ExtractedEntity> modeled;
    try {
      modeled = await model.extract(text);
    } on EntityExtractionUnavailable {
      return ruleHits;
    }
    return mergeEntityExtractions(ruleHits, modeled);
  }
}

/// Locked rule types are never retyped by the model. Everything else may be
/// upgraded (term → person/org/place) or added when the rules saw nothing.
List<ExtractedEntity> mergeEntityExtractions(
  List<ExtractedEntity> rules,
  List<ExtractedEntity> modeled,
) {
  const locked = {EntityType.money, EntityType.date, EntityType.identifier};

  final merged = List<ExtractedEntity>.from(rules);
  for (final model in modeled) {
    final overlap = merged.indexWhere(
      (rule) =>
          rule.text.toLowerCase() == model.text.toLowerCase() ||
          (rule.start < model.end && model.start < rule.end),
    );
    if (overlap >= 0) {
      final rule = merged[overlap];
      if (locked.contains(rule.type)) continue;
      merged[overlap] = ExtractedEntity(
        text: rule.text,
        type: model.type,
        start: rule.start,
        end: rule.end,
      );
    } else {
      merged.add(model);
    }
  }

  merged.sort((a, b) => a.start.compareTo(b.start));
  final seen = <ExtractedEntity>{};
  final ordered = <ExtractedEntity>[];
  for (final entity in merged) {
    if (seen.add(entity)) ordered.add(entity);
  }
  return List.unmodifiable(ordered);
}

/// Aligns model JSON to UTF-16 spans in [source]. Mentions that do not occur
/// verbatim are dropped so a hallucinated name cannot become a citation.
List<ExtractedEntity> parseModelNerJson(String raw, String source) {
  final slice = _jsonArraySlice(raw);
  if (slice == null) return const [];
  Object decoded;
  try {
    decoded = jsonDecode(slice) as Object;
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];

  final positioned = <ExtractedEntity>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final text = item['text'];
    final typeName = item['type'];
    if (text is! String || typeName is! String || text.isEmpty) continue;
    final type = _typeNamed(typeName);
    if (type == null) continue;
    final start = source.indexOf(text);
    if (start < 0) continue;
    positioned.add(
      ExtractedEntity(
        text: text,
        type: type,
        start: start,
        end: start + text.length,
      ),
    );
  }

  positioned.sort((a, b) => a.start.compareTo(b.start));
  final seen = <ExtractedEntity>{};
  final ordered = <ExtractedEntity>[];
  for (final entity in positioned) {
    if (seen.add(entity)) ordered.add(entity);
  }
  return List.unmodifiable(ordered);
}

String? _jsonArraySlice(String raw) {
  final start = raw.indexOf('[');
  final end = raw.lastIndexOf(']');
  if (start < 0 || end <= start) return null;
  return raw.substring(start, end + 1);
}

EntityType? _typeNamed(String name) {
  for (final type in EntityType.values) {
    if (type.name == name) return type;
  }
  return null;
}
