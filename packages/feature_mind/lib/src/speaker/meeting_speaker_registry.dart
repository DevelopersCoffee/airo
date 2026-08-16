import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Per-meeting speaker display names and merge aliases (`sp2` → `sp0`).
@immutable
class MeetingSpeakerRegistry {
  const MeetingSpeakerRegistry({
    this.displayNames = const {},
    this.mergeInto = const {},
  });

  final Map<String, String> displayNames;
  final Map<String, String> mergeInto;

  static const empty = MeetingSpeakerRegistry();

  String canonicalLabel(String label) {
    final merged = mergeInto[label];
    if (merged != null && merged.isNotEmpty) {
      return canonicalLabel(merged);
    }
    return label;
  }

  String? displayNameFor(String label) {
    final canonical = canonicalLabel(label);
    return displayNames[canonical];
  }

  MeetingSpeakerRegistry renameSpeaker({
    required String label,
    required String displayName,
  }) {
    final canonical = canonicalLabel(label);
    final trimmed = displayName.trim();
    final nextNames = Map<String, String>.from(displayNames);
    if (trimmed.isEmpty) {
      nextNames.remove(canonical);
    } else {
      nextNames[canonical] = trimmed;
    }
    return MeetingSpeakerRegistry(
      displayNames: nextNames,
      mergeInto: mergeInto,
    );
  }

  MeetingSpeakerRegistry mergeSpeakers({
    required String fromLabel,
    required String intoLabel,
  }) {
    final from = canonicalLabel(fromLabel);
    final into = canonicalLabel(intoLabel);
    if (from == into) return this;
    final nextMerge = Map<String, String>.from(mergeInto);
    nextMerge[from] = into;
    return MeetingSpeakerRegistry(
      displayNames: displayNames,
      mergeInto: nextMerge,
    );
  }

  Map<String, Object?> toJson() => {
    'displayNames': displayNames,
    'mergeInto': mergeInto,
  };

  factory MeetingSpeakerRegistry.fromJson(Map<String, Object?> json) =>
      MeetingSpeakerRegistry(
        displayNames: Map<String, String>.from(
          (json['displayNames'] as Map?)?.cast<String, String>() ?? const {},
        ),
        mergeInto: Map<String, String>.from(
          (json['mergeInto'] as Map?)?.cast<String, String>() ?? const {},
        ),
      );

  String encode() => jsonEncode(toJson());

  static MeetingSpeakerRegistry decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return MeetingSpeakerRegistry.fromJson(decoded);
      }
      if (decoded is Map) {
        return MeetingSpeakerRegistry.fromJson(decoded.cast<String, Object?>());
      }
    } catch (_) {
      return empty;
    }
    return empty;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeetingSpeakerRegistry &&
          displayNames == other.displayNames &&
          mergeInto == other.mergeInto;

  @override
  int get hashCode => Object.hash(displayNames, mergeInto);
}
