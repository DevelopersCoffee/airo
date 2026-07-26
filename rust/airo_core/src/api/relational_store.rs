use rusqlite::Connection;

const MIGRATION_V1: &str = include_str!("../../migrations/0001_media_sync_relational.sql");

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RelationalStoreStatus {
    pub schema_version: u32,
    pub foreign_keys_enabled: bool,
}

pub fn initialize_relational_store(path: String) -> Result<RelationalStoreStatus, String> {
    if path.trim().is_empty() {
        return Err("database_path_empty".to_string());
    }
    let mut connection = Connection::open(path).map_err(|_| "database_open_failed".to_string())?;
    apply_migration(&mut connection)
}

fn apply_migration(connection: &mut Connection) -> Result<RelationalStoreStatus, String> {
    connection
        .pragma_update(None, "foreign_keys", "ON")
        .map_err(|_| "foreign_key_enable_failed".to_string())?;
    let transaction = connection
        .transaction()
        .map_err(|_| "migration_transaction_failed".to_string())?;
    transaction
        .execute_batch(MIGRATION_V1)
        .map_err(|_| "migration_v1_failed".to_string())?;
    transaction
        .commit()
        .map_err(|_| "migration_commit_failed".to_string())?;
    let version = connection
        .query_row(
            "SELECT COALESCE(MAX(version), 0) FROM schema_migrations",
            [],
            |row| row.get::<_, u32>(0),
        )
        .map_err(|_| "migration_version_read_failed".to_string())?;
    let foreign_keys = connection
        .query_row("PRAGMA foreign_keys", [], |row| row.get::<_, u32>(0))
        .map_err(|_| "foreign_key_state_read_failed".to_string())?;
    Ok(RelationalStoreStatus {
        schema_version: version,
        foreign_keys_enabled: foreign_keys == 1,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::params;

    #[test]
    fn migration_is_idempotent_and_enables_foreign_keys() {
        let mut connection = Connection::open_in_memory().unwrap();
        let first = apply_migration(&mut connection).unwrap();
        let second = apply_migration(&mut connection).unwrap();
        let migration_count: u32 = connection
            .query_row("SELECT COUNT(*) FROM schema_migrations", [], |row| {
                row.get(0)
            })
            .unwrap();

        assert_eq!(first.schema_version, 1);
        assert!(first.foreign_keys_enabled);
        assert_eq!(second, first);
        assert_eq!(migration_count, 1);
    }

    #[test]
    fn normalized_graph_answers_actor_and_year_query() {
        let mut connection = Connection::open_in_memory().unwrap();
        apply_migration(&mut connection).unwrap();
        connection
            .execute(
                "INSERT INTO media_titles(uuid, title, release_year) VALUES
                 ('old', 'Old Film', 2010), ('new', 'New Film', 2020)",
                [],
            )
            .unwrap();
        connection
            .execute(
                "INSERT INTO media_entities(uuid, entity_type, name)
                 VALUES ('actor-x', 'actor', 'Actor X')",
                [],
            )
            .unwrap();
        connection
            .execute(
                "INSERT INTO media_edges(title_uuid, entity_uuid)
                 VALUES ('old', 'actor-x'), ('new', 'actor-x')",
                [],
            )
            .unwrap();

        let mut statement = connection
            .prepare(
                "SELECT title.uuid FROM media_titles title
                 JOIN media_edges edge ON edge.title_uuid = title.uuid
                 JOIN media_entities entity ON entity.uuid = edge.entity_uuid
                 WHERE entity.entity_type = ?1 AND entity.name = ?2
                   AND title.release_year > ?3
                 ORDER BY title.title, title.uuid",
            )
            .unwrap();
        let ids: Vec<String> = statement
            .query_map(params!["actor", "Actor X", 2015], |row| row.get(0))
            .unwrap()
            .collect::<Result<_, _>>()
            .unwrap();

        assert_eq!(ids, vec!["new"]);
    }

    #[test]
    fn sync_fields_and_vector_counters_round_trip_as_rows() {
        let mut connection = Connection::open_in_memory().unwrap();
        apply_migration(&mut connection).unwrap();
        connection
            .execute(
                "INSERT INTO sync_entities
                 (uuid, entity_type, schema_version, entity_version, updated_at)
                 VALUES ('favorite-a', 'favorite', '1.0.0', 1, 100)",
                [],
            )
            .unwrap();
        connection
            .execute(
                "INSERT INTO sync_fields
                 (entity_uuid, field_name, value_type, boolean_value, updated_at, origin_node_id)
                 VALUES ('favorite-a', 'favorite', 'boolean', 1, 100, 'phone')",
                [],
            )
            .unwrap();
        connection
            .execute(
                "INSERT INTO sync_vector_counters
                 (entity_uuid, field_name, node_id, counter)
                 VALUES ('favorite-a', 'favorite', 'phone', 2),
                        ('favorite-a', 'favorite', 'tv', 1)",
                [],
            )
            .unwrap();

        let value: i64 = connection
            .query_row(
                "SELECT boolean_value FROM sync_fields
                 WHERE entity_uuid = 'favorite-a' AND field_name = 'favorite'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        let counters: Vec<(String, u64)> = connection
            .prepare(
                "SELECT node_id, counter FROM sync_vector_counters
                 WHERE entity_uuid = 'favorite-a' AND field_name = 'favorite'
                 ORDER BY node_id",
            )
            .unwrap()
            .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
            .unwrap()
            .collect::<Result<_, _>>()
            .unwrap();

        assert_eq!(value, 1);
        assert_eq!(
            counters,
            vec![("phone".to_string(), 2), ("tv".to_string(), 1)]
        );
    }

    #[test]
    fn profile_cascade_removes_owned_rows_and_foreign_keys_fail_closed() {
        let mut connection = Connection::open_in_memory().unwrap();
        apply_migration(&mut connection).unwrap();
        connection
            .execute(
                "INSERT INTO users(uuid, created_at, updated_at) VALUES ('u', 1, 1)",
                [],
            )
            .unwrap();
        connection
            .execute(
                "INSERT INTO profiles(uuid, user_uuid, display_name, created_at, updated_at)
                 VALUES ('p', 'u', 'Profile', 1, 1)",
                [],
            )
            .unwrap();
        connection
            .execute(
                "INSERT INTO settings
                 (profile_uuid, setting_key, value_type, boolean_value, updated_at)
                 VALUES ('p', 'captions', 'boolean', 1, 1)",
                [],
            )
            .unwrap();
        connection
            .execute("DELETE FROM profiles WHERE uuid = 'p'", [])
            .unwrap();
        let remaining: u32 = connection
            .query_row("SELECT COUNT(*) FROM settings", [], |row| row.get(0))
            .unwrap();
        let invalid = connection.execute(
            "INSERT INTO favorites
             (uuid, profile_uuid, channel_uuid, created_at, updated_at)
             VALUES ('f', 'missing', 'missing', 1, 1)",
            [],
        );

        assert_eq!(remaining, 0);
        assert!(invalid.is_err());
    }
}
