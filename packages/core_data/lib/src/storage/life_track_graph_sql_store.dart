import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import 'life_track_sql_schema.dart';

/// Shared LifeTrack graph persistence over sqflite [DatabaseExecutor].
class LifeTrackGraphSqlStore {
  LifeTrackGraphSqlStore(this._executor);

  final DatabaseExecutor _executor;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  Future<void> ensureSchema({bool includeIdempotency = true}) async {
    for (final statement in LifeTrackSqlSchema.createStatements(
      includeIdempotency: includeIdempotency,
    )) {
      await _executor.execute(statement);
    }
  }

  Future<void> createTrack(LifeTrack track) async {
    await _runInTransaction((txn) async {
      await _insertTrackGraph(txn, track);
    });
    _notifyChanged();
  }

  Future<LifeTrack?> getTrack(String id) async {
    final rows = await _executor.query(
      LifeTrackSqlSchema.lifeTracksTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _hydrateTrack(_executor, rows.single);
  }

  Future<List<LifeTrack>> listTracks({TrackStatus? status}) async {
    final rows = await _executor.query(
      LifeTrackSqlSchema.lifeTracksTable,
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.name],
      orderBy: 'updated_at DESC',
    );
    return [
      for (final row in rows) await _hydrateTrack(_executor, row),
    ];
  }

  Future<void> updateTrack(LifeTrack track) async {
    await _runInTransaction((txn) async {
      await txn.update(
        LifeTrackSqlSchema.lifeTracksTable,
        {
          'title': track.title,
          'category': track.category.name,
          'status': track.status.name,
          'template_id': track.templateId,
          'created_at': track.createdAt.millisecondsSinceEpoch,
          'updated_at': track.updatedAt.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [track.id],
      );
      await _replaceMilestones(txn, track.id, track.milestones);
    });
    _notifyChanged();
  }

  Future<void> deleteTrack(String id) async {
    await _executor.delete(
      LifeTrackSqlSchema.lifeTracksTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChanged();
  }

  Future<void> updateMilestone(Milestone milestone) async {
    await _executor.update(
      LifeTrackSqlSchema.milestonesTable,
      {
        'track_id': milestone.trackId,
        'name': milestone.name,
        'objective': milestone.objective,
        'sort_order': milestone.sortOrder,
        'status': milestone.status.name,
      },
      where: 'id = ?',
      whereArgs: [milestone.id],
    );
    await _replaceActionItems(_executor, milestone.id, milestone.actionItems);
    _notifyChanged();
  }

  Future<void> updateActionItem(ActionItem item) async {
    await _executor.update(
      LifeTrackSqlSchema.actionItemsTable,
      {
        'milestone_id': item.milestoneId,
        'summary': item.summary,
        'description': item.description,
        'status': item.status.name,
        'due_date': item.dueDate?.millisecondsSinceEpoch,
        'notes': item.notes,
        'created_at': item.createdAt.millisecondsSinceEpoch,
        'updated_at': item.updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await _replaceRequirements(_executor, item.id, item.requirements);
    _notifyChanged();
  }

  Future<void> updateItemStatus(String itemId, ItemStatus status) async {
    await _executor.update(
      LifeTrackSqlSchema.actionItemsTable,
      {
        'status': status.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
    _notifyChanged();
  }

  Future<void> saveInputValue(String requirementId, String value) async {
    await _executor.update(
      LifeTrackSqlSchema.inputRequirementsTable,
      {'value': value},
      where: 'id = ?',
      whereArgs: [requirementId],
    );
    _notifyChanged();
  }

  Future<void> hydrateTemplate(LifeTrack track) async {
    await _runInTransaction((txn) async {
      await _insertTrackGraph(txn, track);
    });
    _notifyChanged();
  }

  Future<void> _runInTransaction(
    Future<void> Function(DatabaseExecutor txn) action,
  ) async {
    final executor = _executor;
    if (executor is Database) {
      await executor.transaction(action);
    } else {
      await action(_executor);
    }
  }

  Future<int> countRows(String table) async {
    final result = await _executor.rawQuery('SELECT COUNT(*) AS count FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> closeChanges() async {
    await _changes.close();
  }

  Future<void> _insertTrackGraph(DatabaseExecutor db, LifeTrack track) async {
    final batch = db.batch();
    batch.insert(LifeTrackSqlSchema.lifeTracksTable, {
      'id': track.id,
      'title': track.title,
      'category': track.category.name,
      'status': track.status.name,
      'template_id': track.templateId,
      'created_at': track.createdAt.millisecondsSinceEpoch,
      'updated_at': track.updatedAt.millisecondsSinceEpoch,
    });
    _queueMilestones(batch, track.milestones);
    await batch.commit(noResult: true);
  }

  Future<void> _replaceMilestones(
    DatabaseExecutor db,
    String trackId,
    List<Milestone> milestones,
  ) async {
    await db.delete(
      LifeTrackSqlSchema.milestonesTable,
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
    final batch = db.batch();
    _queueMilestones(batch, milestones);
    await batch.commit(noResult: true);
  }

  Future<void> _replaceActionItems(
    DatabaseExecutor db,
    String milestoneId,
    List<ActionItem> items,
  ) async {
    await db.delete(
      LifeTrackSqlSchema.actionItemsTable,
      where: 'milestone_id = ?',
      whereArgs: [milestoneId],
    );
    final batch = db.batch();
    _queueActionItems(batch, items);
    await batch.commit(noResult: true);
  }

  Future<void> _replaceRequirements(
    DatabaseExecutor db,
    String actionItemId,
    List<InputRequirement> requirements,
  ) async {
    await db.delete(
      LifeTrackSqlSchema.inputRequirementsTable,
      where: 'action_item_id = ?',
      whereArgs: [actionItemId],
    );
    final batch = db.batch();
    _queueRequirements(batch, requirements);
    await batch.commit(noResult: true);
  }

  void _queueMilestones(Batch batch, List<Milestone> milestones) {
    for (final milestone in milestones) {
      batch.insert(LifeTrackSqlSchema.milestonesTable, {
        'id': milestone.id,
        'track_id': milestone.trackId,
        'name': milestone.name,
        'objective': milestone.objective,
        'sort_order': milestone.sortOrder,
        'status': milestone.status.name,
      });
      _queueActionItems(batch, milestone.actionItems);
    }
  }

  void _queueActionItems(Batch batch, List<ActionItem> items) {
    for (final item in items) {
      batch.insert(LifeTrackSqlSchema.actionItemsTable, {
        'id': item.id,
        'milestone_id': item.milestoneId,
        'summary': item.summary,
        'description': item.description,
        'status': item.status.name,
        'due_date': item.dueDate?.millisecondsSinceEpoch,
        'notes': item.notes,
        'created_at': item.createdAt.millisecondsSinceEpoch,
        'updated_at': item.updatedAt.millisecondsSinceEpoch,
      });
      _queueRequirements(batch, item.requirements);
    }
  }

  void _queueRequirements(Batch batch, List<InputRequirement> requirements) {
    for (final requirement in requirements) {
      batch.insert(LifeTrackSqlSchema.inputRequirementsTable, {
        'id': requirement.id,
        'action_item_id': requirement.actionItemId,
        'label': requirement.label,
        'field_type': requirement.fieldType.name,
        'value': requirement.value,
        'is_required': requirement.isRequired ? 1 : 0,
        'hint': requirement.hint,
      });
    }
  }

  Future<LifeTrack> _hydrateTrack(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final milestonesRows = await db.query(
      LifeTrackSqlSchema.milestonesTable,
      where: 'track_id = ?',
      whereArgs: [row['id']],
      orderBy: 'sort_order ASC',
    );

    final milestones = <Milestone>[];
    for (final milestoneRow in milestonesRows) {
      final actionItemRows = await db.query(
        LifeTrackSqlSchema.actionItemsTable,
        where: 'milestone_id = ?',
        whereArgs: [milestoneRow['id']],
        orderBy: 'created_at ASC',
      );
      final actionItems = <ActionItem>[];
      for (final actionItemRow in actionItemRows) {
        final requirementRows = await db.query(
          LifeTrackSqlSchema.inputRequirementsTable,
          where: 'action_item_id = ?',
          whereArgs: [actionItemRow['id']],
          orderBy: 'label ASC',
        );
        final requirements = requirementRows
            .map(_mapRequirement)
            .toList(growable: false);
        actionItems.add(_mapActionItem(actionItemRow, requirements));
      }
      milestones.add(_mapMilestone(milestoneRow, actionItems));
    }

    return LifeTrack(
      id: row['id']! as String,
      title: row['title']! as String,
      category: LifeTrackCategory.values.firstWhere(
        (item) => item.name == row['category'],
      ),
      status: TrackStatus.values.firstWhere(
        (item) => item.name == row['status'],
      ),
      milestones: milestones,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at']! as int,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at']! as int,
        isUtc: true,
      ),
      templateId: row['template_id'] as String?,
    );
  }

  Milestone _mapMilestone(
    Map<String, Object?> row,
    List<ActionItem> actionItems,
  ) => Milestone(
    id: row['id']! as String,
    trackId: row['track_id']! as String,
    name: row['name']! as String,
    objective: row['objective']! as String,
    sortOrder: row['sort_order']! as int,
    status: ItemStatus.values.firstWhere((item) => item.name == row['status']),
    actionItems: actionItems,
  );

  ActionItem _mapActionItem(
    Map<String, Object?> row,
    List<InputRequirement> requirements,
  ) => ActionItem(
    id: row['id']! as String,
    milestoneId: row['milestone_id']! as String,
    summary: row['summary']! as String,
    description: row['description'] as String?,
    status: ItemStatus.values.firstWhere((item) => item.name == row['status']),
    requirements: requirements,
    dueDate: row['due_date'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            row['due_date']! as int,
            isUtc: true,
          ),
    notes: row['notes'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at']! as int,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ),
  );

  InputRequirement _mapRequirement(Map<String, Object?> row) =>
      InputRequirement(
        id: row['id']! as String,
        actionItemId: row['action_item_id']! as String,
        label: row['label']! as String,
        fieldType: FieldType.values.firstWhere(
          (item) => item.name == row['field_type'],
        ),
        value: row['value'] as String?,
        isRequired: (row['is_required']! as int) == 1,
        hint: row['hint'] as String?,
      );

  void _notifyChanged() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }
}
