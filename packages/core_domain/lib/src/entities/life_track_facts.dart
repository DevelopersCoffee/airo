import 'action_item.dart';
import 'life_track.dart';

/// Applies user-provided field values onto a LifeTrack by requirement label.
class LifeTrackFactPatch {
  const LifeTrackFactPatch();

  static const documentsReceivedKey = '_documents_received';
  static const appendLabels = {
    'Follow-up Log',
    'Evidence Notes',
    'Progress Notes',
  };

  LifeTrack apply({
    required LifeTrack track,
    required Map<String, String> facts,
    required DateTime now,
  }) {
    final documentsReceived = facts[documentsReceivedKey]?.trim();
    final labeledFacts = Map<String, String>.from(facts)
      ..remove(documentsReceivedKey);

    final milestones = track.milestones
        .map((milestone) {
          final items = milestone.actionItems
              .map((item) {
                final requirements = item.requirements
                    .map((requirement) {
                      var value = requirement.value;
                      final incoming = _valueFor(
                        requirement.label,
                        labeledFacts,
                      );
                      if (incoming != null) {
                        value = _mergeValue(
                          label: requirement.label,
                          existing: value,
                          incoming: incoming,
                        );
                      }
                      if (documentsReceived != null &&
                          documentsReceived.isNotEmpty &&
                          requirement.fieldType == FieldType.document) {
                        value = documentsReceived;
                      }
                      return requirement.copyWith(value: value);
                    })
                    .toList(growable: false);

                final filledRequired = requirements
                    .where((requirement) => requirement.isRequired)
                    .every((requirement) => _hasValue(requirement.value));
                final nextStatus =
                    filledRequired && requirements.any((r) => r.isRequired)
                    ? ItemStatus.done
                    : item.status;

                return item.copyWith(
                  requirements: requirements,
                  status: nextStatus,
                  updatedAt: now,
                );
              })
              .toList(growable: false);

          return milestone.copyWith(
            actionItems: items,
            status: _deriveMilestoneStatus(items),
          );
        })
        .toList(growable: false);

    return track.copyWith(milestones: milestones, updatedAt: now);
  }

  String? requirementValue(LifeTrack track, String label) {
    final needle = _normalize(label);
    for (final milestone in track.milestones) {
      for (final item in milestone.actionItems) {
        for (final requirement in item.requirements) {
          if (_normalize(requirement.label) == needle) {
            return requirement.value;
          }
        }
      }
    }
    return null;
  }

  String? _valueFor(String label, Map<String, String> facts) {
    final needle = _normalize(label);
    for (final entry in facts.entries) {
      if (_normalize(entry.key) == needle && entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
    return null;
  }

  String _mergeValue({
    required String label,
    required String? existing,
    required String incoming,
  }) {
    if (!appendLabels.contains(label) || !_hasValue(existing)) {
      return incoming;
    }
    if (existing!.contains(incoming)) return existing;
    return '$existing\n$incoming';
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  String _normalize(String value) => value.toLowerCase().trim();

  ItemStatus _deriveMilestoneStatus(List<ActionItem> items) {
    if (items.isEmpty) return ItemStatus.todo;
    if (items.every((item) => item.status == ItemStatus.skipped)) {
      return ItemStatus.skipped;
    }
    if (items.every(
      (item) =>
          item.status == ItemStatus.done || item.status == ItemStatus.skipped,
    )) {
      return ItemStatus.done;
    }
    if (items.any((item) => item.status == ItemStatus.blocked)) {
      return ItemStatus.blocked;
    }
    if (items.any((item) => item.status == ItemStatus.inProgress)) {
      return ItemStatus.inProgress;
    }
    if (items.any((item) => item.status == ItemStatus.done)) {
      return ItemStatus.inProgress;
    }
    return ItemStatus.todo;
  }
}
