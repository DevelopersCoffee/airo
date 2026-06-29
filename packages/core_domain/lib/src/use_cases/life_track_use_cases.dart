import 'dart:convert';

import '../entities/action_item.dart';
import '../entities/life_track.dart';
import '../errors/app_error.dart';
import '../repositories/life_track_repository.dart';
import '../result/result.dart';
import '../state/track_state_machine.dart';
import 'use_case.dart';

class CreateTrackUseCase implements UseCase<LifeTrack, LifeTrack> {
  CreateTrackUseCase(this._repository);

  final LifeTrackRepository _repository;

  @override
  Future<Result<LifeTrack>> call(LifeTrack input) {
    return _repository.createTrack(input);
  }
}

class ListTracksQuery {
  const ListTracksQuery({this.status, this.category});

  final TrackStatus? status;
  final LifeTrackCategory? category;
}

class ListTracksUseCase implements UseCase<ListTracksQuery, List<LifeTrack>> {
  ListTracksUseCase(this._repository);

  final LifeTrackRepository _repository;

  @override
  Future<Result<List<LifeTrack>>> call(ListTracksQuery input) async {
    final result = await _repository.listTracks(status: input.status);
    if (result case Err<List<LifeTrack>>()) {
      return result;
    }

    final tracks = result.value;
    if (input.category == null) {
      return Ok(tracks);
    }

    return Ok(
      tracks
          .where((track) => track.category == input.category)
          .toList(growable: false),
    );
  }
}

class GetTrackDetailUseCase implements UseCase<String, LifeTrack> {
  GetTrackDetailUseCase(this._repository);

  final LifeTrackRepository _repository;

  @override
  Future<Result<LifeTrack>> call(String input) {
    return _repository.getTrack(input);
  }
}

class UpdateItemStatusCommand {
  const UpdateItemStatusCommand({
    required this.trackId,
    required this.itemId,
    required this.status,
  });

  final String trackId;
  final String itemId;
  final ItemStatus status;
}

class UpdateItemStatusUseCase
    implements UseCase<UpdateItemStatusCommand, LifeTrack> {
  UpdateItemStatusUseCase(this._repository);

  final LifeTrackRepository _repository;

  @override
  Future<Result<LifeTrack>> call(UpdateItemStatusCommand input) async {
    final trackResult = await _repository.getTrack(input.trackId);
    if (trackResult case Err<LifeTrack>()) {
      return trackResult;
    }

    try {
      final now = DateTime.now().toUtc();
      final updatedTrack = _updateTrackItemStatus(
        trackResult.value,
        input.itemId,
        input.status,
        now,
      );
      final saveResult = await _repository.updateTrack(updatedTrack);
      if (saveResult case Err<void>(error: final error, stack: final stack)) {
        return Err(error, stack);
      }
      return Ok(updatedTrack);
    } catch (error, stack) {
      return Err(error, stack);
    }
  }

  LifeTrack _updateTrackItemStatus(
    LifeTrack track,
    String itemId,
    ItemStatus targetStatus,
    DateTime updatedAt,
  ) {
    var found = false;
    final updatedMilestones = track.milestones
        .map((milestone) {
          var changed = false;
          final updatedItems = milestone.actionItems
              .map((item) {
                if (item.id != itemId) return item;

                found = true;
                changed = true;
                TrackStateMachine.transition(item.status, targetStatus);
                return item.copyWith(
                  status: targetStatus,
                  updatedAt: updatedAt,
                );
              })
              .toList(growable: false);

          if (!changed) return milestone;
          return milestone.copyWith(
            actionItems: updatedItems,
            status: _deriveMilestoneStatus(updatedItems),
          );
        })
        .toList(growable: false);

    if (!found) {
      throw NotFoundError('LifeTrack action item not found: $itemId');
    }

    final updatedTrack = track.copyWith(
      milestones: updatedMilestones,
      updatedAt: updatedAt,
    );
    return updatedTrack.copyWith(
      status: TrackStateMachine.computeTrackStatus(updatedTrack),
    );
  }

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

class SaveInputValueCommand {
  const SaveInputValueCommand({
    required this.requirementId,
    required this.value,
  });

  final String requirementId;
  final Object? value;
}

class SaveInputValueUseCase implements NoOutputUseCase<SaveInputValueCommand> {
  SaveInputValueUseCase(this._repository);

  final LifeTrackRepository _repository;

  @override
  Future<Result<void>> call(SaveInputValueCommand input) {
    return _repository.saveInputValue(
      input.requirementId,
      _serializeValue(input.value),
    );
  }

  String _serializeValue(Object? value) {
    if (value == null) return '';
    return switch (value) {
      String text => text,
      bool flag => flag.toString(),
      num number => number.toString(),
      DateTime dateTime => dateTime.toUtc().toIso8601String(),
      Uri uri => uri.toString(),
      Iterable<String> values => jsonEncode(values.toList(growable: false)),
      _ => value.toString(),
    };
  }
}
