use rusqlite::{params, Connection, OptionalExtension};

const MIGRATION_V1: &str = include_str!("../../migrations/0001_media_sync_relational.sql");

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RelationalStoreStatus {
    pub schema_version: u32,
    pub foreign_keys_enabled: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RelationalSyncCounter {
    pub node_id: String,
    pub counter: u64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RelationalSyncField {
    pub name: String,
    pub value_type: String,
    pub text_value: Option<String>,
    pub integer_value: Option<i64>,
    pub real_value: Option<f64>,
    pub boolean_value: Option<bool>,
    pub updated_at_micros: i64,
    pub origin_node_id: String,
    pub clock: Vec<RelationalSyncCounter>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RelationalSyncEntity {
    pub uuid: String,
    pub entity_type: String,
    pub schema_version: String,
    pub entity_version: u32,
    pub updated_at_micros: i64,
    pub deleted_at_micros: Option<i64>,
    pub clock: Vec<RelationalSyncCounter>,
    pub deletion_clock: Vec<RelationalSyncCounter>,
    pub fields: Vec<RelationalSyncField>,
}

pub fn initialize_relational_store(path: String) -> Result<RelationalStoreStatus, String> {
    if path.trim().is_empty() {
        return Err("database_path_empty".to_string());
    }
    let mut connection = Connection::open(path).map_err(|_| "database_open_failed".to_string())?;
    apply_migration(&mut connection)
}

pub fn upsert_relational_sync_entity(
    path: String,
    entity: RelationalSyncEntity,
) -> Result<(), String> {
    validate_sync_entity(&entity)?;
    let mut connection = Connection::open(path).map_err(|_| "database_open_failed".to_string())?;
    apply_migration(&mut connection)?;
    let transaction = connection
        .transaction()
        .map_err(|_| "sync_transaction_failed".to_string())?;
    transaction
        .execute(
            "INSERT INTO sync_entities
             (uuid, entity_type, schema_version, entity_version, updated_at, deleted_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(uuid) DO UPDATE SET
               entity_type = excluded.entity_type,
               schema_version = excluded.schema_version,
               entity_version = excluded.entity_version,
               updated_at = excluded.updated_at,
               deleted_at = excluded.deleted_at",
            params![
                entity.uuid,
                entity.entity_type,
                entity.schema_version,
                entity.entity_version,
                entity.updated_at_micros,
                entity.deleted_at_micros
            ],
        )
        .map_err(|_| "sync_entity_write_failed".to_string())?;
    transaction
        .execute(
            "DELETE FROM sync_fields WHERE entity_uuid = ?1",
            [&entity.uuid],
        )
        .map_err(|_| "sync_field_replace_failed".to_string())?;
    transaction
        .execute(
            "DELETE FROM sync_vector_counters WHERE entity_uuid = ?1",
            [&entity.uuid],
        )
        .map_err(|_| "sync_clock_replace_failed".to_string())?;
    insert_counters(&transaction, &entity.uuid, "", &entity.clock)?;
    insert_counters(
        &transaction,
        &entity.uuid,
        "$deleted",
        &entity.deletion_clock,
    )?;
    for field in &entity.fields {
        transaction
            .execute(
                "INSERT INTO sync_fields
                 (entity_uuid, field_name, value_type, text_value, integer_value,
                  real_value, boolean_value, updated_at, origin_node_id)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
                params![
                    entity.uuid,
                    field.name,
                    field.value_type,
                    field.text_value,
                    field.integer_value,
                    field.real_value,
                    field.boolean_value,
                    field.updated_at_micros,
                    field.origin_node_id
                ],
            )
            .map_err(|_| "sync_field_write_failed".to_string())?;
        insert_counters(&transaction, &entity.uuid, &field.name, &field.clock)?;
    }
    transaction
        .commit()
        .map_err(|_| "sync_commit_failed".to_string())
}

pub fn read_relational_sync_entity(
    path: String,
    uuid: String,
) -> Result<Option<RelationalSyncEntity>, String> {
    let mut connection = Connection::open(path).map_err(|_| "database_open_failed".to_string())?;
    apply_migration(&mut connection)?;
    let entity = connection
        .query_row(
            "SELECT entity_type, schema_version, entity_version, updated_at, deleted_at
             FROM sync_entities WHERE uuid = ?1",
            [&uuid],
            |row| {
                Ok(RelationalSyncEntity {
                    uuid: uuid.clone(),
                    entity_type: row.get(0)?,
                    schema_version: row.get(1)?,
                    entity_version: row.get(2)?,
                    updated_at_micros: row.get(3)?,
                    deleted_at_micros: row.get(4)?,
                    clock: Vec::new(),
                    deletion_clock: Vec::new(),
                    fields: Vec::new(),
                })
            },
        )
        .optional()
        .map_err(|_| "sync_entity_read_failed".to_string())?;
    let Some(mut entity) = entity else {
        return Ok(None);
    };
    entity.clock = read_counters(&connection, &uuid, "")?;
    entity.deletion_clock = read_counters(&connection, &uuid, "$deleted")?;
    let mut statement = connection
        .prepare(
            "SELECT field_name, value_type, text_value, integer_value, real_value,
                    boolean_value, updated_at, origin_node_id
             FROM sync_fields WHERE entity_uuid = ?1 ORDER BY field_name",
        )
        .map_err(|_| "sync_field_query_failed".to_string())?;
    let rows = statement
        .query_map([&uuid], |row| {
            Ok(RelationalSyncField {
                name: row.get(0)?,
                value_type: row.get(1)?,
                text_value: row.get(2)?,
                integer_value: row.get(3)?,
                real_value: row.get(4)?,
                boolean_value: row.get(5)?,
                updated_at_micros: row.get(6)?,
                origin_node_id: row.get(7)?,
                clock: Vec::new(),
            })
        })
        .map_err(|_| "sync_field_read_failed".to_string())?;
    entity.fields = rows
        .collect::<Result<Vec<_>, _>>()
        .map_err(|_| "sync_field_decode_failed".to_string())?;
    drop(statement);
    for field in &mut entity.fields {
        field.clock = read_counters(&connection, &uuid, &field.name)?;
    }
    Ok(Some(entity))
}

fn validate_sync_entity(entity: &RelationalSyncEntity) -> Result<(), String> {
    if entity.uuid.trim().is_empty()
        || entity.entity_type.trim().is_empty()
        || entity.schema_version.trim().is_empty()
        || entity.entity_version == 0
        || entity.deleted_at_micros.is_some() == entity.deletion_clock.is_empty()
    {
        return Err("sync_entity_invalid".to_string());
    }
    for field in &entity.fields {
        let populated = [
            field.text_value.is_some(),
            field.integer_value.is_some(),
            field.real_value.is_some(),
            field.boolean_value.is_some(),
        ]
        .into_iter()
        .filter(|value| *value)
        .count();
        let expected = if field.value_type == "null" { 0 } else { 1 };
        if field.name.trim().is_empty()
            || field.name == "$deleted"
            || field.origin_node_id.trim().is_empty()
            || !matches!(
                field.value_type.as_str(),
                "null" | "text" | "integer" | "real" | "boolean"
            )
            || populated != expected
        {
            return Err("sync_field_invalid".to_string());
        }
    }
    Ok(())
}

fn insert_counters(
    transaction: &rusqlite::Transaction<'_>,
    uuid: &str,
    field_name: &str,
    counters: &[RelationalSyncCounter],
) -> Result<(), String> {
    for counter in counters {
        if counter.node_id.trim().is_empty() {
            return Err("sync_counter_invalid".to_string());
        }
        transaction
            .execute(
                "INSERT INTO sync_vector_counters
                 (entity_uuid, field_name, node_id, counter)
                 VALUES (?1, ?2, ?3, ?4)",
                params![uuid, field_name, counter.node_id, counter.counter],
            )
            .map_err(|_| "sync_counter_write_failed".to_string())?;
    }
    Ok(())
}

fn read_counters(
    connection: &Connection,
    uuid: &str,
    field_name: &str,
) -> Result<Vec<RelationalSyncCounter>, String> {
    let mut statement = connection
        .prepare(
            "SELECT node_id, counter FROM sync_vector_counters
             WHERE entity_uuid = ?1 AND field_name = ?2 ORDER BY node_id",
        )
        .map_err(|_| "sync_counter_query_failed".to_string())?;
    let counters = statement
        .query_map(params![uuid, field_name], |row| {
            Ok(RelationalSyncCounter {
                node_id: row.get(0)?,
                counter: row.get(1)?,
            })
        })
        .map_err(|_| "sync_counter_read_failed".to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|_| "sync_counter_decode_failed".to_string())?;
    Ok(counters)
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
    fn sync_entity_api_round_trips_scalar_fields_and_all_clock_scopes() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("sync.sqlite");
        let entity = RelationalSyncEntity {
            uuid: "favorite-a".to_string(),
            entity_type: "favorite".to_string(),
            schema_version: "1.0.0".to_string(),
            entity_version: 2,
            updated_at_micros: 200,
            deleted_at_micros: Some(250),
            clock: vec![RelationalSyncCounter {
                node_id: "phone".to_string(),
                counter: 2,
            }],
            deletion_clock: vec![RelationalSyncCounter {
                node_id: "tv".to_string(),
                counter: 3,
            }],
            fields: vec![RelationalSyncField {
                name: "favorite".to_string(),
                value_type: "boolean".to_string(),
                text_value: None,
                integer_value: None,
                real_value: None,
                boolean_value: Some(true),
                updated_at_micros: 175,
                origin_node_id: "phone".to_string(),
                clock: vec![
                    RelationalSyncCounter {
                        node_id: "phone".to_string(),
                        counter: 2,
                    },
                    RelationalSyncCounter {
                        node_id: "tv".to_string(),
                        counter: 1,
                    },
                ],
            }],
        };

        upsert_relational_sync_entity(path.to_string_lossy().into_owned(), entity.clone()).unwrap();
        let loaded =
            read_relational_sync_entity(path.to_string_lossy().into_owned(), entity.uuid.clone())
                .unwrap();

        assert_eq!(loaded, Some(entity));
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
