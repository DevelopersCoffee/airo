import 'package:equatable/equatable.dart';

import 'compact_epg_models.dart';

enum CompactEpgEventResolutionCode {
  resolved('resolved'),
  missingEventId('missing_event_id'),
  unresolved('unresolved');

  const CompactEpgEventResolutionCode(this.stableId);

  final String stableId;
}

class CompactEpgResolvedEvent extends Equatable {
  const CompactEpgResolvedEvent({
    required this.eventId,
    required this.entry,
    required this.program,
  });

  final String eventId;
  final CompactEpgEntry entry;
  final CompactEpgProgram program;

  @override
  List<Object?> get props => [eventId, entry, program];
}

class CompactEpgEventResolution extends Equatable {
  const CompactEpgEventResolution._({required this.code, this.resolved});

  factory CompactEpgEventResolution.resolved(CompactEpgResolvedEvent event) {
    return CompactEpgEventResolution._(
      code: CompactEpgEventResolutionCode.resolved,
      resolved: event,
    );
  }

  const CompactEpgEventResolution.missingEventId()
    : this._(code: CompactEpgEventResolutionCode.missingEventId);

  const CompactEpgEventResolution.unresolved()
    : this._(code: CompactEpgEventResolutionCode.unresolved);

  final CompactEpgEventResolutionCode code;
  final CompactEpgResolvedEvent? resolved;

  bool get isResolved => resolved != null;

  @override
  List<Object?> get props => [code, resolved];
}

class CompactEpgEventResolver {
  const CompactEpgEventResolver();

  CompactEpgEventResolution resolve({
    required CompactEpgSlice slice,
    required String eventId,
  }) {
    final trimmedEventId = eventId.trim();
    if (trimmedEventId.isEmpty) {
      return const CompactEpgEventResolution.missingEventId();
    }

    for (final entry in slice.entries) {
      for (final program in [entry.current, entry.next]) {
        if (program?.eventId == trimmedEventId) {
          return CompactEpgEventResolution.resolved(
            CompactEpgResolvedEvent(
              eventId: trimmedEventId,
              entry: entry,
              program: program!,
            ),
          );
        }
      }
    }

    return const CompactEpgEventResolution.unresolved();
  }
}
