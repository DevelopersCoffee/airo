/// Shared LifeTrack SQL schema used by plaintext and encrypted destinations.
class LifeTrackSqlSchema {
  static const schemaVersion = 2;
  static const metaTable = 'lifetrack_meta';
  static const lifeTracksTable = 'life_tracks';
  static const milestonesTable = 'milestones';
  static const actionItemsTable = 'action_items';
  static const inputRequirementsTable = 'input_requirements';
  static const idempotentEffectsTable = 'lifetrack_idempotent_effects';

  static const metaKeyMigrationComplete = 'migration_complete';
  static const metaKeyPlaintextBackupPath = 'plaintext_backup_path';
  static const metaKeySchemaVersion = 'schema_version';
  static const metaKeyEncryptionEnabled = 'encryption_enabled';

  static List<String> createStatements({bool includeIdempotency = true}) {
    final statements = <String>[
      '''
      CREATE TABLE IF NOT EXISTS $metaTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS $lifeTracksTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        template_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS $milestonesTable (
        id TEXT PRIMARY KEY,
        track_id TEXT NOT NULL REFERENCES $lifeTracksTable(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        objective TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'todo'
      )
      ''',
      '''
      CREATE TABLE IF NOT EXISTS $actionItemsTable (
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
      ''',
      '''
      CREATE TABLE IF NOT EXISTS $inputRequirementsTable (
        id TEXT PRIMARY KEY,
        action_item_id TEXT NOT NULL REFERENCES $actionItemsTable(id) ON DELETE CASCADE,
        label TEXT NOT NULL,
        field_type TEXT NOT NULL,
        value TEXT,
        is_required INTEGER NOT NULL DEFAULT 0,
        hint TEXT
      )
      ''',
      'CREATE INDEX IF NOT EXISTS idx_milestones_track_id ON $milestonesTable(track_id)',
      'CREATE INDEX IF NOT EXISTS idx_action_items_milestone_id ON $actionItemsTable(milestone_id)',
      'CREATE INDEX IF NOT EXISTS idx_input_requirements_action_item_id ON $inputRequirementsTable(action_item_id)',
    ];

    if (includeIdempotency) {
      statements.add('''
        CREATE TABLE IF NOT EXISTS $idempotentEffectsTable (
          idempotency_key TEXT PRIMARY KEY,
          confirmation_hash TEXT NOT NULL,
          effect_state TEXT NOT NULL,
          destination_receipt TEXT,
          resource_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    }

    return statements;
  }
}
