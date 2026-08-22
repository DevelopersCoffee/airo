import 'package:core_domain/core_domain.dart';

import '../../../addons/templates/addon_life_track_record_policy.dart';
import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';
import '../../domain/services/lifetrack_confirmation_token_service.dart';

class LifeTrackRecordConnector implements AgentConnector {
  LifeTrackRecordConnector({
    required LifeTrackRepository repository,
    required Future<LifeTrackTemplate?> Function(String templateId)
    resolveTemplate,
    this.ensureInitialized,
    DateTime Function()? now,
    String Function()? newTrackId,
    LifeTrackFactPatch patch = const LifeTrackFactPatch(),
    String Function(String templateId)? followUpHint,
    List<String> Function(String templateId)? dedupeFieldLabels,
    LifeTrackConfirmationTokenService? confirmationTokens,
    Future<bool> Function()? writeGate,
    IdempotentEffectPort? idempotencyPort,
  }) : _repository = repository,
       _resolveTemplate = resolveTemplate,
       _now = now ?? DateTime.now,
       _newTrackId = newTrackId ?? _defaultTrackId,
       _patch = patch,
       _followUpHint = followUpHint ?? _defaultFollowUpHint,
       _dedupeFieldLabels = dedupeFieldLabels ?? _defaultDedupeFieldLabels,
       _confirmationTokens =
           confirmationTokens ?? LifeTrackConfirmationTokenService(),
       _writeGate = writeGate,
       _idempotencyPort = idempotencyPort;

  final LifeTrackRepository _repository;
  final Future<LifeTrackTemplate?> Function(String templateId) _resolveTemplate;
  final Future<void> Function()? ensureInitialized;
  final DateTime Function() _now;
  final String Function() _newTrackId;
  final LifeTrackFactPatch _patch;
  final String Function(String templateId) _followUpHint;
  final List<String> Function(String templateId) _dedupeFieldLabels;
  final LifeTrackConfirmationTokenService _confirmationTokens;
  final Future<bool> Function()? _writeGate;
  final IdempotentEffectPort? _idempotencyPort;

  static String _defaultFollowUpHint(String templateId) {
    if (templateId == 'study_progress_v1') {
      return AddonLifeTrackRecordPolicy.defaultStudyFollowUp;
    }
    return AddonLifeTrackRecordPolicy.defaultClaimFollowUp;
  }

  static List<String> _defaultDedupeFieldLabels(String templateId) {
    if (templateId == 'study_progress_v1') {
      return const ['Subject', 'Last Topic', 'Exam Date'];
    }
    return AddonLifeTrackRecordPolicy.defaultDedupeFields;
  }

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

    if (_writeGate != null && !await _writeGate!()) {
      return const ConnectorResult.error(
        code: 'addon_write_failed',
        message:
            'LifeTrack writes require encrypted storage on this device. '
            'Open Settings to finish secure storage setup, then try again.',
      );
    }

    final payload = {
      'title': title,
      'template_id': templateId,
      'facts': facts,
    };

    final preview = _preview(
      title: title,
      templateId: templateId,
      facts: facts,
    );

    final token = arguments['confirmation_token'] as String?;
    final legacyConfirmed =
        arguments['confirmed'] == true && arguments['source'] == 'user_confirm';
    if (token == null && !legacyConfirmed) {
      final issued = _confirmationTokens.issue(
        destinationTool: name,
        payload: payload,
      );
      return ConnectorResult.error(
        code: 'confirmation_required',
        message: '$preview\n\nReply yes to save this journey on this device.',
        data: {
          'pending': {
            ...payload,
            'confirmed': true,
            'source': 'user_confirm',
          },
          'confirmation_token': issued,
        },
      );
    }

    if (token != null) {
      final tokenError = _confirmationTokens.validateAndConsume(
        token: token,
        destinationTool: name,
        payload: payload,
      );
      if (tokenError != null) {
        return ConnectorResult.error(
          code: tokenError,
          message: 'That save confirmation expired or no longer matches. '
              'Ask me to save again and confirm the new preview.',
        );
      }
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

    final idempotencyKey =
        arguments['idempotency_key'] as String? ??
        'lifetrack:${updated.id}:${_confirmationTokens.confirmationHashFor(
          destinationTool: name,
          payload: payload,
        )}';
    final confirmationHash = _confirmationTokens.confirmationHashFor(
      destinationTool: name,
      payload: payload,
    );

    if (_idempotencyPort != null) {
      final existingEffect = await _idempotencyPort!.findByKey(idempotencyKey);
      if (existingEffect case Ok<IdempotentEffectRecord?>(value: final record)) {
        if (record != null &&
            record.state == IdempotentEffectState.committed) {
          final trackResult = await _repository.getTrack(updated.id);
          if (trackResult case Ok<LifeTrack>(value: final track)) {
            return ConnectorResult(
              data: {
                'source': 'local_lifetrack_repository',
                'created': created,
                'track_id': track.id,
                'title': track.title,
                'template_id': track.templateId,
                'markdown': _savedMessage(track, created: created),
                'idempotent_replay': true,
              },
              message: _savedMessage(track, created: created),
            );
          }
        }
      }
      final begin = await _idempotencyPort!.beginEffect(
        idempotencyKey: idempotencyKey,
        confirmationHash: confirmationHash,
        resourceId: updated.id,
      );
      if (begin case Err<IdempotentEffectRecord>(error: final error)) {
        return ConnectorResult.error(
          code: 'addon_write_failed',
          message: error.toString(),
        );
      }
    }

    if (created) {
      final createResult = await _repository.createTrack(updated);
      if (createResult case Err<LifeTrack>(error: final error)) {
        if (_idempotencyPort != null) {
          await _idempotencyPort!.markFailed(idempotencyKey);
        }
        return ConnectorResult.error(
          code: 'lifetrack_write_failed',
          message: error.toString(),
        );
      }
    } else {
      final updateResult = await _repository.updateTrack(updated);
      if (updateResult case Err<void>(error: final error)) {
        if (_idempotencyPort != null) {
          await _idempotencyPort!.markFailed(idempotencyKey);
        }
        return ConnectorResult.error(
          code: 'lifetrack_write_failed',
          message: error.toString(),
        );
      }
    }

    if (_idempotencyPort != null) {
      await _idempotencyPort!.commitEffect(
        idempotencyKey: idempotencyKey,
        destinationReceipt: updated.id,
      );
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
    final dedupeLabels = _dedupeFieldLabels(templateId);
    for (final track in tracks) {
      if (track.templateId != templateId) continue;
      if (_valuesMatch(track, claimId) ||
          _valuesMatch(track, policyNumber) ||
          _valuesMatch(track, intermediaryRef) ||
          _valuesMatch(track, subject) ||
          _matchesDedupeLabels(track, facts, dedupeLabels) ||
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

  bool _matchesDedupeLabels(
    LifeTrack track,
    Map<String, String> facts,
    List<String> labels,
  ) {
    for (final label in labels) {
      final value = facts[label];
      if (value != null && _valuesMatch(track, value)) return true;
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
    return '$verb local LifeTrack "${track.title}". ${_followUpHint(track.templateId ?? '')}';
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
