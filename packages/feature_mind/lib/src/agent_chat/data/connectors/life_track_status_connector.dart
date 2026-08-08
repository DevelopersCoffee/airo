import 'package:core_domain/core_domain.dart';

import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';

class LifeTrackStatusResult {
  const LifeTrackStatusResult({
    required this.markdown,
    required this.matchedTracks,
    required this.data,
  });

  final String markdown;
  final List<String> matchedTracks;
  final Map<String, dynamic> data;
}

class LifeTrackStatusFormatter {
  const LifeTrackStatusFormatter();

  LifeTrackStatusResult format({
    required String query,
    required List<LifeTrack> tracks,
  }) {
    final activeTracks = tracks
        .where((track) => track.status != TrackStatus.postponed)
        .toList(growable: false);
    final matchedTracks = _matchTracks(query, activeTracks);
    if (matchedTracks.isEmpty) {
      final label = _querySubject(query) ?? 'that request';
      return LifeTrackStatusResult(
        markdown:
            'I could not find a LifeTrack matching "$label". I will not guess from incomplete local data.',
        matchedTracks: const [],
        data: const {'matched_tracks': <String>[]},
      );
    }

    final wantsDocuments = _wantsDocuments(query);
    if (wantsDocuments) {
      return _formatDocuments(matchedTracks);
    }
    return _formatPendingStatus(matchedTracks);
  }

  String proactiveSummary(List<LifeTrack> tracks) {
    final activeTracks = tracks
        .where((track) => track.status != TrackStatus.postponed)
        .toList(growable: false);
    if (activeTracks.isEmpty) {
      return 'No active LifeTrack goals need proactive prompts right now.';
    }

    final lines = activeTracks.map((track) {
      final pending = _pendingItems(track).length;
      final percent = (track.progress * 100).round();
      return '- ${track.title}: $percent% complete, $pending pending item${pending == 1 ? '' : 's'}';
    });
    return 'Active LifeTrack goals:\n${lines.join('\n')}';
  }

  LifeTrackStatusResult _formatPendingStatus(List<LifeTrack> tracks) {
    final buffer = StringBuffer();
    final rows = <Map<String, dynamic>>[];
    var pendingCount = 0;

    for (final track in tracks) {
      final pending = _pendingItems(track);
      pendingCount += pending.length;
      buffer.writeln('LifeTrack status for ${track.title}');
      buffer.writeln();
      buffer.writeln(
        '| Milestone | Pending item | Status | Due | Missing required documents |',
      );
      buffer.writeln('| --- | --- | --- | --- | --- |');
      if (pending.isEmpty) {
        buffer.writeln('| — | No pending items | — | — | — |');
      } else {
        for (final entry in pending) {
          final missingDocs = entry.item.requirements
              .where(_isMissingRequiredDocument)
              .map((requirement) => requirement.label)
              .join(', ');
          final due = _formatDate(entry.item.dueDate);
          buffer.writeln(
            '| ${_escapeCell(entry.milestone.name)} | ${_escapeCell(entry.item.summary)} | ${entry.item.status.name} | $due | ${_escapeCell(missingDocs.isEmpty ? '—' : missingDocs)} |',
          );
          rows.add({
            'track_id': track.id,
            'track_title': track.title,
            'milestone': entry.milestone.name,
            'summary': entry.item.summary,
            'status': entry.item.status.name,
            'due_date': entry.item.dueDate?.toIso8601String(),
            'missing_required_documents': entry.item.requirements
                .where(_isMissingRequiredDocument)
                .map((requirement) => requirement.label)
                .toList(growable: false),
          });
        }
      }
      buffer.writeln();
    }

    return LifeTrackStatusResult(
      markdown: buffer.toString().trimRight(),
      matchedTracks: tracks.map((track) => track.id).toList(growable: false),
      data: {
        'matched_tracks': tracks.map(_trackData).toList(growable: false),
        'pending_count': pendingCount,
        'rows': rows,
      },
    );
  }

  LifeTrackStatusResult _formatDocuments(List<LifeTrack> tracks) {
    final buffer = StringBuffer();
    final rows = <Map<String, dynamic>>[];

    for (final track in tracks) {
      buffer.writeln('Required documents for ${track.title}');
      buffer.writeln();
      buffer.writeln('| Document | Status | Related item |');
      buffer.writeln('| --- | --- | --- |');
      var foundDocument = false;
      for (final milestone in track.milestones) {
        for (final item in milestone.actionItems) {
          for (final requirement in item.requirements.where(_isDocument)) {
            foundDocument = true;
            final status = _hasValue(requirement.value)
                ? 'provided'
                : 'missing';
            buffer.writeln(
              '| ${_escapeCell(requirement.label)} | $status | ${_escapeCell(item.summary)} |',
            );
            rows.add({
              'track_id': track.id,
              'track_title': track.title,
              'document': requirement.label,
              'status': status,
              'related_item': item.summary,
            });
          }
        }
      }
      if (!foundDocument) {
        buffer.writeln('| — | No document requirements found | — |');
      }
      buffer.writeln();
    }

    return LifeTrackStatusResult(
      markdown: buffer.toString().trimRight(),
      matchedTracks: tracks.map((track) => track.id).toList(growable: false),
      data: {
        'matched_tracks': tracks.map(_trackData).toList(growable: false),
        'documents': rows,
      },
    );
  }

  List<LifeTrack> _matchTracks(String query, List<LifeTrack> tracks) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return tracks;

    final matches = tracks
        .where((track) {
          final haystack = _normalize(
            [
              track.title,
              track.category.name,
              track.templateId ?? '',
            ].join(' '),
          );
          if (haystack.split(' ').any(normalizedQuery.split(' ').contains)) {
            return true;
          }
          return _categoryAliases(track.category).any(normalizedQuery.contains);
        })
        .toList(growable: false);

    return matches;
  }

  String? _querySubject(String query) {
    final normalized = _normalize(query);
    final myMatch = RegExp(
      r'my ([a-z0-9 ]+?) (track|goal)',
    ).firstMatch(normalized);
    if (myMatch != null) return myMatch.group(1);
    final onMatch = RegExp(
      r'on ([a-z0-9 ]+?) (track|goal)',
    ).firstMatch(normalized);
    if (onMatch != null) return onMatch.group(1);
    return null;
  }

  bool _wantsDocuments(String query) {
    final normalized = _normalize(query);
    return normalized.contains('document') ||
        normalized.contains('documents') ||
        normalized.contains('paperwork') ||
        normalized.contains('driving');
  }

  List<_PendingItem> _pendingItems(LifeTrack track) {
    final items = <_PendingItem>[];
    for (final milestone in track.milestones) {
      for (final item in milestone.actionItems) {
        if (item.status == ItemStatus.done ||
            item.status == ItemStatus.skipped) {
          continue;
        }
        items.add(_PendingItem(milestone: milestone, item: item));
      }
    }
    return items;
  }

  Map<String, dynamic> _trackData(LifeTrack track) => {
    'id': track.id,
    'title': track.title,
    'category': track.category.name,
    'status': track.status.name,
    'progress': track.progress,
  };

  bool _isMissingRequiredDocument(InputRequirement requirement) {
    return _isDocument(requirement) &&
        requirement.isRequired &&
        !_hasValue(requirement.value);
  }

  bool _isDocument(InputRequirement requirement) {
    return requirement.fieldType == FieldType.document;
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '—';
    final utc = dateTime.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
  }

  String _escapeCell(String value) => value.replaceAll('|', '\\|').trim();

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _categoryAliases(LifeTrackCategory category) {
    return switch (category) {
      LifeTrackCategory.realEstate => const [
        'flat',
        'home',
        'house',
        'property',
        'real estate',
      ],
      LifeTrackCategory.carPurchase => const [
        'car',
        'vehicle',
        'driving',
        'rto',
      ],
      LifeTrackCategory.medical => const ['medical', 'health', 'doctor'],
      LifeTrackCategory.education => const ['education', 'study', 'college'],
      LifeTrackCategory.insurance => const ['insurance'],
      LifeTrackCategory.finance => const ['finance', 'money', 'loan'],
      LifeTrackCategory.travel => const ['travel', 'trip', 'passport', 'visa'],
      LifeTrackCategory.legal => const ['legal', 'law'],
      LifeTrackCategory.custom => const ['custom'],
    };
  }
}

class LifeTrackStatusConnector implements AgentConnector {
  LifeTrackStatusConnector({
    required this._repository,
    this._formatter = const LifeTrackStatusFormatter(),
    this._ensureInitialized,
  });

  final LifeTrackRepository _repository;
  final LifeTrackStatusFormatter _formatter;
  final Future<void> Function()? _ensureInitialized;

  @override
  String get name => 'query_lifetrack_status';

  @override
  Set<SkillCapability> get requiredCapabilities => const {
    SkillCapability.lifeTrackRead,
  };

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String?;
    if (query == null || query.trim().isEmpty) {
      return const ConnectorResult.error(
        code: 'missing_query',
        message: 'LifeTrack status queries require a non-empty query.',
      );
    }

    await _ensureInitialized?.call();

    final tracksResult = await _repository.listTracks();
    if (tracksResult case Err<List<LifeTrack>>(error: final error)) {
      return ConnectorResult.error(
        code: 'lifetrack_query_failed',
        message: error.toString(),
      );
    }

    final formatted = _formatter.format(
      query: query,
      tracks: tracksResult.value,
    );
    return ConnectorResult(
      data: {
        'source': 'local_lifetrack_repository',
        'markdown': formatted.markdown,
        ...formatted.data,
      },
      message: formatted.markdown,
    );
  }
}

class _PendingItem {
  const _PendingItem({required this.milestone, required this.item});

  final Milestone milestone;
  final ActionItem item;
}
