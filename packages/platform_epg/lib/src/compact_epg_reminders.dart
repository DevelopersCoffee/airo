import 'package:equatable/equatable.dart';

import 'compact_epg_event_resolver.dart';
import 'compact_epg_models.dart';

enum CompactEpgReminderAction {
  schedule('schedule'),
  none('none');

  const CompactEpgReminderAction(this.stableId);

  final String stableId;
}

enum CompactEpgReminderStatus {
  scheduled('scheduled'),
  unchanged('unchanged'),
  unresolved('unresolved'),
  skippedPastNotification('skipped_past_notification');

  const CompactEpgReminderStatus(this.stableId);

  final String stableId;
}

class CompactEpgReminderRequest extends Equatable {
  const CompactEpgReminderRequest({
    required this.reminderId,
    required this.title,
    this.eventId,
    this.channelId,
    this.programId,
    this.remindBefore = const Duration(minutes: 5),
  });

  final String reminderId;
  final String title;
  final String? eventId;
  final String? channelId;
  final String? programId;
  final Duration remindBefore;

  @override
  List<Object?> get props => [
    reminderId,
    title,
    eventId,
    channelId,
    programId,
    remindBefore,
  ];
}

class CompactEpgPendingReminder extends Equatable {
  const CompactEpgPendingReminder({
    required this.request,
    required this.scheduledChannelId,
    required this.scheduledProgramId,
    required this.programStartsAt,
    required this.notifyAt,
  });

  final CompactEpgReminderRequest request;
  final String scheduledChannelId;
  final String scheduledProgramId;
  final DateTime programStartsAt;
  final DateTime notifyAt;

  @override
  List<Object?> get props => [
    request,
    scheduledChannelId,
    scheduledProgramId,
    programStartsAt,
    notifyAt,
  ];
}

class CompactEpgReminderCommand extends Equatable {
  const CompactEpgReminderCommand({
    required this.action,
    required this.reminderId,
    required this.title,
    required this.channelId,
    required this.programId,
    required this.programStartsAt,
    required this.notifyAt,
    this.eventId,
  });

  final CompactEpgReminderAction action;
  final String reminderId;
  final String title;
  final String channelId;
  final String programId;
  final String? eventId;
  final DateTime programStartsAt;
  final DateTime notifyAt;

  @override
  List<Object?> get props => [
    action,
    reminderId,
    title,
    channelId,
    programId,
    eventId,
    programStartsAt,
    notifyAt,
  ];
}

class CompactEpgReminderReconcileResult extends Equatable {
  const CompactEpgReminderReconcileResult({
    required this.request,
    required this.status,
    this.command,
    this.pending,
  });

  final CompactEpgReminderRequest request;
  final CompactEpgReminderStatus status;
  final CompactEpgReminderCommand? command;
  final CompactEpgPendingReminder? pending;

  @override
  List<Object?> get props => [request, status, command, pending];
}

class CompactEpgReminderReconciler {
  const CompactEpgReminderReconciler({
    this.eventResolver = const CompactEpgEventResolver(),
  });

  final CompactEpgEventResolver eventResolver;

  List<CompactEpgReminderReconcileResult> reconcileAll({
    required Iterable<CompactEpgReminderRequest> requests,
    required CompactEpgSlice slice,
    required DateTime now,
    Iterable<CompactEpgPendingReminder> existing = const [],
  }) {
    final existingById = {
      for (final pending in existing) pending.request.reminderId: pending,
    };
    return [
      for (final request in requests)
        reconcileOne(
          request: request,
          slice: slice,
          now: now,
          existing: existingById[request.reminderId],
        ),
    ];
  }

  CompactEpgReminderReconcileResult reconcileOne({
    required CompactEpgReminderRequest request,
    required CompactEpgSlice slice,
    required DateTime now,
    CompactEpgPendingReminder? existing,
  }) {
    final resolved = _resolve(request: request, slice: slice);
    if (resolved == null) {
      return CompactEpgReminderReconcileResult(
        request: request,
        status: CompactEpgReminderStatus.unresolved,
      );
    }

    final notifyAt = resolved.program.startsAt.toUtc().subtract(
      request.remindBefore,
    );
    if (!notifyAt.isAfter(now.toUtc())) {
      return CompactEpgReminderReconcileResult(
        request: request,
        status: CompactEpgReminderStatus.skippedPastNotification,
      );
    }

    final pending = CompactEpgPendingReminder(
      request: request,
      scheduledChannelId: resolved.entry.channelId,
      scheduledProgramId: resolved.program.programId,
      programStartsAt: resolved.program.startsAt.toUtc(),
      notifyAt: notifyAt,
    );

    if (pending == existing) {
      return CompactEpgReminderReconcileResult(
        request: request,
        status: CompactEpgReminderStatus.unchanged,
        pending: pending,
      );
    }

    return CompactEpgReminderReconcileResult(
      request: request,
      status: CompactEpgReminderStatus.scheduled,
      pending: pending,
      command: CompactEpgReminderCommand(
        action: CompactEpgReminderAction.schedule,
        reminderId: request.reminderId,
        title: request.title,
        channelId: resolved.entry.channelId,
        programId: resolved.program.programId,
        eventId: resolved.program.eventId ?? request.eventId,
        programStartsAt: resolved.program.startsAt.toUtc(),
        notifyAt: notifyAt,
      ),
    );
  }

  CompactEpgResolvedEvent? _resolve({
    required CompactEpgReminderRequest request,
    required CompactEpgSlice slice,
  }) {
    final eventId = request.eventId;
    if (eventId != null && eventId.trim().isNotEmpty) {
      return eventResolver.resolve(slice: slice, eventId: eventId).resolved;
    }

    final channelId = request.channelId;
    final programId = request.programId;
    if (channelId == null || programId == null) return null;

    final entry = slice.entryForChannel(channelId);
    if (entry == null) return null;

    for (final program in [entry.current, entry.next]) {
      if (program?.programId == programId) {
        return CompactEpgResolvedEvent(
          eventId: program!.eventId ?? program.programId,
          entry: entry,
          program: program,
        );
      }
    }

    return null;
  }
}
