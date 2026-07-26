import 'package:equatable/equatable.dart';

import 'compact_epg_models.dart';

const String kIntelligentEpgNotificationSchemaVersion = '1.0.0';

enum IntelligentEpgTriggerType { programStart, followedEntityLive }

enum IntelligentEpgTriggerReason {
  favoriteChannel,
  followedEntityTitle,
  followedEntityCategory,
}

class EpgQuietHours extends Equatable {
  const EpgQuietHours({
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
  }) : assert(startMinuteOfDay >= 0 && startMinuteOfDay < 1440),
       assert(endMinuteOfDay >= 0 && endMinuteOfDay < 1440);

  final int startMinuteOfDay;
  final int endMinuteOfDay;

  bool contains(DateTime localTime) {
    if (startMinuteOfDay == endMinuteOfDay) return false;
    final minute = localTime.hour * 60 + localTime.minute;
    if (startMinuteOfDay < endMinuteOfDay) {
      return minute >= startMinuteOfDay && minute < endMinuteOfDay;
    }
    return minute >= startMinuteOfDay || minute < endMinuteOfDay;
  }

  @override
  List<Object?> get props => [startMinuteOfDay, endMinuteOfDay];
}

class EpgNotificationReceipt extends Equatable {
  const EpgNotificationReceipt({
    required this.triggerId,
    required this.deliveredAt,
  });

  final String triggerId;
  final DateTime deliveredAt;

  @override
  List<Object?> get props => [triggerId, deliveredAt];
}

class IntelligentEpgNotificationPolicy extends Equatable {
  IntelligentEpgNotificationPolicy({
    required this.maxDeliveriesPerWindow,
    required this.frequencyWindow,
    required this.lookahead,
    this.quietHours,
  }) {
    if (maxDeliveriesPerWindow < 0 ||
        frequencyWindow <= Duration.zero ||
        lookahead < Duration.zero) {
      throw ArgumentError('Notification policy bounds are invalid');
    }
  }

  final int maxDeliveriesPerWindow;
  final Duration frequencyWindow;
  final Duration lookahead;
  final EpgQuietHours? quietHours;

  @override
  List<Object?> get props => [
    maxDeliveriesPerWindow,
    frequencyWindow,
    lookahead,
    quietHours,
  ];
}

class IntelligentEpgSignals extends Equatable {
  IntelligentEpgSignals({
    Iterable<String> favoriteChannelIds = const [],
    Iterable<String> followedEntities = const [],
  }) : favoriteChannelIds = Set.unmodifiable(favoriteChannelIds),
       followedEntities = Set.unmodifiable(
         followedEntities.map(_normalize).where((value) => value.isNotEmpty),
       );

  final Set<String> favoriteChannelIds;
  final Set<String> followedEntities;

  @override
  List<Object?> get props => [favoriteChannelIds, followedEntities];
}

class IntelligentEpgTrigger extends Equatable {
  const IntelligentEpgTrigger({
    required this.triggerId,
    required this.type,
    required this.reason,
    required this.channelId,
    required this.programId,
    required this.programTitle,
    required this.scheduledAt,
  });

  final String triggerId;
  final IntelligentEpgTriggerType type;
  final IntelligentEpgTriggerReason reason;
  final String channelId;
  final String programId;
  final String programTitle;
  final DateTime scheduledAt;

  @override
  List<Object?> get props => [
    triggerId,
    type,
    reason,
    channelId,
    programId,
    programTitle,
    scheduledAt,
  ];
}

class IntelligentEpgTriggerEngine {
  const IntelligentEpgTriggerEngine();

  List<IntelligentEpgTrigger> select({
    required CompactEpgWindow window,
    required IntelligentEpgSignals signals,
    required IntelligentEpgNotificationPolicy policy,
    required DateTime now,
    Iterable<EpgNotificationReceipt> deliveryReceipts = const [],
  }) {
    if (window.isExpired(now) ||
        window.availabilityAt(now) != CompactEpgAvailability.available ||
        policy.maxDeliveriesPerWindow == 0) {
      return const [];
    }
    final cutoff = now.subtract(policy.frequencyWindow);
    final recentReceipts = deliveryReceipts
        .where(
          (receipt) =>
              !receipt.deliveredAt.isBefore(cutoff) &&
              !receipt.deliveredAt.isAfter(now),
        )
        .toList();
    final remaining = policy.maxDeliveriesPerWindow - recentReceipts.length;
    if (remaining <= 0) return const [];
    final deliveredIds = {
      for (final receipt in recentReceipts) receipt.triggerId,
    };
    final latest = now.add(policy.lookahead);
    final candidates = <String, IntelligentEpgTrigger>{};

    for (final entry in window.entries) {
      for (final program in entry.programs) {
        if (!program.endsAt.isAfter(program.startsAt) ||
            !program.endsAt.isAfter(now) ||
            program.startsAt.isAfter(latest)) {
          continue;
        }
        final scheduledAt = program.startsAt.isAfter(now)
            ? program.startsAt
            : now;
        if (policy.quietHours?.contains(scheduledAt) ?? false) continue;

        if (signals.favoriteChannelIds.contains(entry.channelId)) {
          _addCandidate(
            candidates,
            type: IntelligentEpgTriggerType.programStart,
            reason: IntelligentEpgTriggerReason.favoriteChannel,
            channelId: entry.channelId,
            program: program,
            scheduledAt: scheduledAt,
          );
        }
        final title = _normalize(program.title);
        final category = _normalize(program.category ?? '');
        for (final entity in signals.followedEntities) {
          if (title.contains(entity)) {
            _addCandidate(
              candidates,
              type: IntelligentEpgTriggerType.followedEntityLive,
              reason: IntelligentEpgTriggerReason.followedEntityTitle,
              channelId: entry.channelId,
              program: program,
              scheduledAt: scheduledAt,
            );
            break;
          }
          if (category.contains(entity)) {
            _addCandidate(
              candidates,
              type: IntelligentEpgTriggerType.followedEntityLive,
              reason: IntelligentEpgTriggerReason.followedEntityCategory,
              channelId: entry.channelId,
              program: program,
              scheduledAt: scheduledAt,
            );
            break;
          }
        }
      }
    }

    final result =
        candidates.values
            .where((candidate) => !deliveredIds.contains(candidate.triggerId))
            .toList()
          ..sort((left, right) {
            final time = left.scheduledAt.compareTo(right.scheduledAt);
            if (time != 0) return time;
            return left.triggerId.compareTo(right.triggerId);
          });
    if (result.length > remaining) {
      return List.unmodifiable(result.take(remaining));
    }
    return List.unmodifiable(result);
  }

  void _addCandidate(
    Map<String, IntelligentEpgTrigger> candidates, {
    required IntelligentEpgTriggerType type,
    required IntelligentEpgTriggerReason reason,
    required String channelId,
    required CompactEpgProgram program,
    required DateTime scheduledAt,
  }) {
    final triggerId =
        '${type.name}:${program.programId}:'
        '${program.startsAt.toUtc().millisecondsSinceEpoch}';
    candidates.putIfAbsent(
      triggerId,
      () => IntelligentEpgTrigger(
        triggerId: triggerId,
        type: type,
        reason: reason,
        channelId: channelId,
        programId: program.programId,
        programTitle: program.title,
        scheduledAt: scheduledAt,
      ),
    );
  }
}

String _normalize(String value) => value.trim().toLowerCase();
