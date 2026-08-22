import 'package:core_domain/core_domain.dart';

import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';

class LifeTrackRecordConnector implements AgentConnector {
  LifeTrackRecordConnector({
    required LifeTrackRepository repository,
    required Future<LifeTrackTemplate?> Function(String templateId)
    resolveTemplate,
    this.ensureInitialized,
    DateTime Function()? now,
    String Function()? newTrackId,
    LifeTrackFactPatch patch = const LifeTrackFactPatch(),
  }) : _repository = repository,
       _resolveTemplate = resolveTemplate,
       _now = now ?? DateTime.now,
       _newTrackId = newTrackId ?? _defaultTrackId,
       _patch = patch;

  final LifeTrackRepository _repository;
  final Future<LifeTrackTemplate?> Function(String templateId) _resolveTemplate;
  final Future<void> Function()? ensureInitialized;
  final DateTime Function() _now;
  final String Function() _newTrackId;
  final LifeTrackFactPatch _patch;

  @override
  String get name => 'record_lifetrack_facts';

  @override
  Set<SkillCapability> get requiredCapabilities => const {
    SkillCapability.lifeTrackWrite,
  };

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final title = (arguments['title'] as String?)?.trim() ?? '';
    final templateId =
        (arguments['template_id'] as String?)?.trim() ?? 'insurance_claim_v1';
    final facts = _stringMap(arguments['facts']);
    if (title.isEmpty || facts.isEmpty) {
      return const ConnectorResult.error(
        code: 'missing_facts',
        message:
            'I need at least a title and one fact before I can store a journey locally.',
      );
    }

    await ensureInitialized?.call();

    final preview = _preview(
      title: title,
      templateId: templateId,
      facts: facts,
    );
    final confirmed =
        arguments['confirmed'] == true && arguments['source'] == 'user_confirm';
    if (!confirmed) {
      return ConnectorResult.error(
        code: 'confirmation_required',
        message: '$preview\n\nReply yes to save this journey on this device.',
        data: {
          'pending': {
            'title': title,
            'template_id': templateId,
            'facts': facts,
            'confirmed': true,
            'source': 'user_confirm',
          },
        },
      );
    }

    final template = await _resolveTemplate(templateId);
    if (template == null) {
      return ConnectorResult.error(
        code: 'template_not_found',
        message: 'The LifeTrack template "$templateId" is not installed.',
      );
    }

    final tracksResult = await _repository.listTracks();
    if (tracksResult case Err<List<LifeTrack>>(error: final error)) {
      return ConnectorResult.error(
        code: 'lifetrack_write_failed',
        message: error.toString(),
      );
    }

    final now = _now().toUtc();
    final existing = _matchExisting(
      tracks: tracksResult.value,
      templateId: templateId,
      title: title,
      facts: facts,
    );
    final created = existing == null;
    final base =
        existing ??
        template.instantiate(trackId: _newTrackId(), title: title, now: now);
    final updated = _patch.apply(
      track: created ? base : base.copyWith(title: title),
      facts: facts,
      now: now,
    );

    if (created) {
      final createResult = await _repository.createTrack(updated);
      if (createResult case Err<LifeTrack>(error: final error)) {
        return ConnectorResult.error(
          code: 'lifetrack_write_failed',
          message: error.toString(),
        );
      }
    } else {
      final updateResult = await _repository.updateTrack(updated);
      if (updateResult case Err<void>(error: final error)) {
        return ConnectorResult.error(
          code: 'lifetrack_write_failed',
          message: error.toString(),
        );
      }
    }

    return ConnectorResult(
      data: {
        'source': 'local_lifetrack_repository',
        'created': created,
        'track_id': updated.id,
        'title': updated.title,
        'template_id': updated.templateId,
        'markdown': _savedMessage(updated, created: created),
      },
      message: _savedMessage(updated, created: created),
    );
  }

  LifeTrack? _matchExisting({
    required List<LifeTrack> tracks,
    required String templateId,
    required String title,
    required Map<String, String> facts,
  }) {
    final claimId = facts['Claim ID'];
    final policyNumber = facts['Policy Number'];
    final intermediaryRef = facts['Intermediary Reference'];
    final subject = facts['Subject'];
    for (final track in tracks) {
      if (track.templateId != templateId) continue;
      if (_valuesMatch(track, claimId) ||
          _valuesMatch(track, policyNumber) ||
          _valuesMatch(track, intermediaryRef) ||
          _valuesMatch(track, subject) ||
          track.title == title) {
        return track;
      }
    }
    final sameTemplate = tracks
        .where((track) => track.templateId == templateId)
        .toList(growable: false);
    if (sameTemplate.length == 1) return sameTemplate.single;
    return null;
  }

  bool _valuesMatch(LifeTrack track, String? needle) {
    if (needle == null || needle.trim().isEmpty) return false;
    final normalized = needle.trim().toLowerCase();
    for (final milestone in track.milestones) {
      for (final item in milestone.actionItems) {
        for (final requirement in item.requirements) {
          if ((requirement.value ?? '').trim().toLowerCase() == normalized) {
            return true;
          }
        }
      }
    }
    return false;
  }

  String _preview({
    required String title,
    required String templateId,
    required Map<String, String> facts,
  }) {
    final lines = facts.entries
        .where((entry) => entry.key != LifeTrackFactPatch.documentsReceivedKey)
        .map((entry) => '- ${entry.key}: ${entry.value}');
    return 'I can save "$title" locally as a $templateId journey:\n${lines.join('\n')}';
  }

  String _savedMessage(LifeTrack track, {required bool created}) {
    final verb = created ? 'Started' : 'Updated';
    final followUp = track.templateId == 'study_progress_v1'
        ? 'Ask what is pending on this study track whenever you want a status check.'
        : 'Ask what is pending on this claim whenever you want a status check.';
    return '$verb local LifeTrack "${track.title}". $followUp';
  }

  Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  static String _defaultTrackId() =>
      'lt_${DateTime.now().toUtc().microsecondsSinceEpoch}';
}
