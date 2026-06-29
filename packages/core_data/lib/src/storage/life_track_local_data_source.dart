import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LifeTrackLocalDataSource {
  LifeTrackLocalDataSource({
    DatabaseFactory? databaseFactory,
    this._databasePath,
    this._databaseName = 'life_track.db',
  }) : _databaseFactory = databaseFactory ?? databaseFactorySqflitePlugin;

  static const schemaVersion = 1;

  static const lifeTracksTable = 'life_tracks';
  static const milestonesTable = 'milestones';
  static const actionItemsTable = 'action_items';
  static const inputRequirementsTable = 'input_requirements';

  final DatabaseFactory _databaseFactory;
  final String? _databasePath;
  final String _databaseName;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Database? _database;

  Future<void> initialize() async {
    if (_database != null && _database!.isOpen) return;

    final resolvedPath =
        _databasePath ?? path.join(await getDatabasesPath(), _databaseName);
    _database = await _databaseFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await _createSchema(db);
          }
        },
      ),
    );
  }

  Future<LifeTrack> createTrack(LifeTrack track) async {
    final db = await _requireDatabase();
    await db.transaction((txn) async {
      await _insertTrackGraph(txn, track);
    });
    await _notifyChanged();
    return track;
  }

  Future<LifeTrack?> getTrack(String id) async {
    final db = await _requireDatabase();
    final rows = await db.query(
      lifeTracksTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _hydrateTrack(db, rows.single);
  }

  Future<List<LifeTrack>> listTracks({TrackStatus? status}) async {
    final db = await _requireDatabase();
    final rows = await db.query(
      lifeTracksTable,
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.name],
      orderBy: 'updated_at DESC',
    );
    return Future.wait(rows.map((row) => _hydrateTrack(db, row)));
  }

  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) async* {
    yield await listTracks(status: status);
    yield* _changes.stream.asyncMap((_) => listTracks(status: status));
  }

  Future<void> updateTrack(LifeTrack track) async {
    final db = await _requireDatabase();
    await db.transaction((txn) async {
      await txn.update(
        lifeTracksTable,
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
    await _notifyChanged();
  }

  Future<void> deleteTrack(String id) async {
    final db = await _requireDatabase();
    await db.delete(lifeTracksTable, where: 'id = ?', whereArgs: [id]);
    await _notifyChanged();
  }

  Future<void> updateMilestone(Milestone milestone) async {
    final db = await _requireDatabase();
    await db.update(
      milestonesTable,
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
    await _replaceActionItems(db, milestone.id, milestone.actionItems);
    await _notifyChanged();
  }

  Future<void> updateActionItem(ActionItem item) async {
    final db = await _requireDatabase();
    await db.update(
      actionItemsTable,
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
    await _replaceRequirements(db, item.id, item.requirements);
    await _notifyChanged();
  }

  Future<void> updateItemStatus(String itemId, ItemStatus status) async {
    final db = await _requireDatabase();
    await db.update(
      actionItemsTable,
      {
        'status': status.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
    await _notifyChanged();
  }

  Future<void> saveInputValue(String requirementId, String value) async {
    final db = await _requireDatabase();
    await db.update(
      inputRequirementsTable,
      {'value': value},
      where: 'id = ?',
      whereArgs: [requirementId],
    );
    await _notifyChanged();
  }

  Future<LifeTrack> hydrateTemplate(LifeTrack track) async {
    final db = await _requireDatabase();
    await db.transaction((txn) async {
      await _insertTrackGraph(txn, track);
    });
    await _notifyChanged();
    return track;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _requireDatabase() async {
    await initialize();
    return _database!;
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $lifeTracksTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        template_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $milestonesTable (
        id TEXT PRIMARY KEY,
        track_id TEXT NOT NULL REFERENCES $lifeTracksTable(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        objective TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'todo'
      )
    ''');
    await db.execute('''
      CREATE TABLE $actionItemsTable (
        id TEXT PRIMARY KEY,
        milestone_id TEXT NOT NULL REFERENCES $milestonesTable(id) ON DELETE CASCADE,
        summary TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'todo',
        due_date INTEGER,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $inputRequirementsTable (
        id TEXT PRIMARY KEY,
        action_item_id TEXT NOT NULL REFERENCES $actionItemsTable(id) ON DELETE CASCADE,
        label TEXT NOT NULL,
        field_type TEXT NOT NULL,
        value TEXT,
        is_required INTEGER NOT NULL DEFAULT 0,
        hint TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_milestones_track_id ON $milestonesTable(track_id)',
    );
    await db.execute(
      'CREATE INDEX idx_action_items_milestone_id ON $actionItemsTable(milestone_id)',
    );
    await db.execute(
      'CREATE INDEX idx_input_requirements_action_item_id ON $inputRequirementsTable(action_item_id)',
    );
  }

  Future<void> _insertTrackGraph(DatabaseExecutor db, LifeTrack track) async {
    await db.insert(lifeTracksTable, {
      'id': track.id,
      'title': track.title,
      'category': track.category.name,
      'status': track.status.name,
      'template_id': track.templateId,
      'created_at': track.createdAt.millisecondsSinceEpoch,
      'updated_at': track.updatedAt.millisecondsSinceEpoch,
    });

    for (final milestone in track.milestones) {
      await db.insert(milestonesTable, {
        'id': milestone.id,
        'track_id': milestone.trackId,
        'name': milestone.name,
        'objective': milestone.objective,
        'sort_order': milestone.sortOrder,
        'status': milestone.status.name,
      });
      for (final item in milestone.actionItems) {
        await db.insert(actionItemsTable, {
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
        for (final requirement in item.requirements) {
          await db.insert(inputRequirementsTable, {
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
    }
  }

  Future<void> _replaceMilestones(
    DatabaseExecutor db,
    String trackId,
    List<Milestone> milestones,
  ) async {
    await db.delete(
      milestonesTable,
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
    for (final milestone in milestones) {
      await db.insert(milestonesTable, {
        'id': milestone.id,
        'track_id': milestone.trackId,
        'name': milestone.name,
        'objective': milestone.objective,
        'sort_order': milestone.sortOrder,
        'status': milestone.status.name,
      });
      for (final item in milestone.actionItems) {
        await db.insert(actionItemsTable, {
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
        for (final requirement in item.requirements) {
          await db.insert(inputRequirementsTable, {
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
    }
  }

  Future<void> _replaceActionItems(
    DatabaseExecutor db,
    String milestoneId,
    List<ActionItem> items,
  ) async {
    await db.delete(
      actionItemsTable,
      where: 'milestone_id = ?',
      whereArgs: [milestoneId],
    );
    for (final item in items) {
      await db.insert(actionItemsTable, {
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
      for (final requirement in item.requirements) {
        await db.insert(inputRequirementsTable, {
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
  }

  Future<void> _replaceRequirements(
    DatabaseExecutor db,
    String actionItemId,
    List<InputRequirement> requirements,
  ) async {
    await db.delete(
      inputRequirementsTable,
      where: 'action_item_id = ?',
      whereArgs: [actionItemId],
    );
    for (final requirement in requirements) {
      await db.insert(inputRequirementsTable, {
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
      milestonesTable,
      where: 'track_id = ?',
      whereArgs: [row['id']],
      orderBy: 'sort_order ASC',
    );

    final milestones = <Milestone>[];
    for (final milestoneRow in milestonesRows) {
      final actionItemRows = await db.query(
        actionItemsTable,
        where: 'milestone_id = ?',
        whereArgs: [milestoneRow['id']],
        orderBy: 'created_at ASC',
      );
      final actionItems = <ActionItem>[];
      for (final actionItemRow in actionItemRows) {
        final requirementRows = await db.query(
          inputRequirementsTable,
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

  Future<void> _notifyChanged() async {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }
}
