import 'dart:convert';

import 'compact_epg_models.dart';

const int kCompactEpgSnapshotJsonVersion = 1;

String encodeCompactEpgSlice(CompactEpgSlice slice) {
  return jsonEncode(compactEpgSliceToJson(slice));
}

CompactEpgSlice decodeCompactEpgSlice(String payload) {
  final decoded = jsonDecode(payload);
  if (decoded is! Map) {
    throw const FormatException('Compact EPG snapshot must be a JSON object.');
  }
  return compactEpgSliceFromJson(Map<String, dynamic>.from(decoded));
}

Map<String, Object?> compactEpgSliceToJson(CompactEpgSlice slice) {
  return {
    'jsonVersion': kCompactEpgSnapshotJsonVersion,
    'schemaVersion': slice.schemaVersion,
    'generatedAt': slice.generatedAt.toUtc().toIso8601String(),
    'expiresAt': slice.expiresAt.toUtc().toIso8601String(),
    'source': slice.source.stableId,
    'entries': slice.entries.map(compactEpgEntryToJson).toList(),
  };
}

CompactEpgSlice compactEpgSliceFromJson(Map<String, dynamic> json) {
  final entries = _requiredList(json, 'entries')
      .map((entry) => compactEpgEntryFromJson(_requiredMap(entry, 'entries')))
      .toList(growable: false);
  return CompactEpgSlice(
    entries: entries,
    generatedAt: _requiredDateTime(json, 'generatedAt'),
    expiresAt: _requiredDateTime(json, 'expiresAt'),
    source: _sliceSourceFromStableId(_requiredString(json, 'source')),
    schemaVersion:
        _optionalString(json, 'schemaVersion') ?? kCompactEpgSchemaVersion,
  );
}

Map<String, Object?> compactEpgEntryToJson(CompactEpgEntry entry) {
  return {
    'schemaVersion': entry.schemaVersion,
    'channelId': entry.channelId,
    'channelName': entry.channelName,
    if (entry.channelNumber != null) 'channelNumber': entry.channelNumber,
    if (entry.current != null)
      'current': compactEpgProgramToJson(entry.current!),
    if (entry.next != null) 'next': compactEpgProgramToJson(entry.next!),
    if (entry.sourceRef != null) 'sourceRef': entry.sourceRef!.value,
  };
}

CompactEpgEntry compactEpgEntryFromJson(Map<String, dynamic> json) {
  final sourceRefValue = _optionalString(json, 'sourceRef');
  return CompactEpgEntry(
    channelId: _requiredString(json, 'channelId'),
    channelName: _requiredString(json, 'channelName'),
    channelNumber: _optionalString(json, 'channelNumber'),
    current: _optionalProgram(json, 'current'),
    next: _optionalProgram(json, 'next'),
    sourceRef: sourceRefValue == null
        ? null
        : _redactedSourceRef(sourceRefValue, 'sourceRef'),
    schemaVersion:
        _optionalString(json, 'schemaVersion') ?? kCompactEpgSchemaVersion,
  );
}

Map<String, Object?> compactEpgProgramToJson(CompactEpgProgram program) {
  return {
    'schemaVersion': program.schemaVersion,
    'programId': program.programId,
    'title': program.title,
    if (program.eventId != null) 'eventId': program.eventId,
    if (program.subtitle != null) 'subtitle': program.subtitle,
    if (program.category != null) 'category': program.category,
    if (program.rating != null) 'rating': program.rating,
    'kind': program.kind.stableId,
    'startsAt': program.startsAt.toUtc().toIso8601String(),
    'endsAt': program.endsAt.toUtc().toIso8601String(),
  };
}

CompactEpgProgram compactEpgProgramFromJson(Map<String, dynamic> json) {
  return CompactEpgProgram(
    programId: _requiredString(json, 'programId'),
    title: _requiredString(json, 'title'),
    eventId: _optionalString(json, 'eventId'),
    subtitle: _optionalString(json, 'subtitle'),
    category: _optionalString(json, 'category'),
    rating: _optionalString(json, 'rating'),
    kind: _optionalProgramKind(json, 'kind') ?? CompactEpgProgramKind.standard,
    startsAt: _requiredDateTime(json, 'startsAt'),
    endsAt: _requiredDateTime(json, 'endsAt'),
    schemaVersion:
        _optionalString(json, 'schemaVersion') ?? kCompactEpgSchemaVersion,
  );
}

CompactEpgProgram? _optionalProgram(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return compactEpgProgramFromJson(_requiredMap(value, key));
}

CompactEpgSliceSource _sliceSourceFromStableId(String value) {
  for (final source in CompactEpgSliceSource.values) {
    if (source.stableId == value) return source;
  }
  throw FormatException('Unknown CompactEpgSliceSource "$value".');
}

CompactEpgProgramKind? _optionalProgramKind(
  Map<String, dynamic> json,
  String key,
) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  for (final kind in CompactEpgProgramKind.values) {
    if (kind.stableId == value) return kind;
  }
  throw FormatException('Unknown CompactEpgProgramKind "$value".');
}

CompactEpgSourceRef _redactedSourceRef(String value, String key) {
  try {
    return CompactEpgSourceRef.redacted(value);
  } on ArgumentError catch (error) {
    throw FormatException('Invalid $key: ${error.message}.');
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Compact EPG snapshot missing string "$key".');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Compact EPG snapshot field "$key" must be a string.');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('Compact EPG snapshot field "$key" is not a date.');
  }
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException('Compact EPG snapshot field "$key" must be a list.');
}

Map<String, dynamic> _requiredMap(Object? value, String key) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Compact EPG snapshot field "$key" must be an object.');
}
