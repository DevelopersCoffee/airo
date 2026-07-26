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

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RelationalMediaTitle {
    pub uuid: String,
    pub title: String,
    pub release_year: u32,
    pub content_rating: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RelationalMediaEntity {
    pub uuid: String,
    pub entity_type: String,
    pub name: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RelationalMediaEdge {
    pub title_uuid: String,
    pub entity_uuid: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RelationalMediaKnowledgePack {
    pub pack_id: String,
    pub schema_version: String,
    pub titles: Vec<RelationalMediaTitle>,
    pub entities: Vec<RelationalMediaEntity>,
    pub edges: Vec<RelationalMediaEdge>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RelationalMediaGraphQuery {
    pub entity_type: Option<String>,
    pub entity_name: Option<String>,
    pub released_after: Option<u32>,
    pub released_before: Option<u32>,
    pub content_rating: Option<String>,
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

pub fn load_relational_media_pack(
    path: String,
    pack: RelationalMediaKnowledgePack,
) -> Result<(), String> {
    validate_media_pack(&pack)?;
    let mut connection = Connection::open(path).map_err(|_| "database_open_failed".to_string())?;
    apply_migration(&mut connection)?;
    let transaction = connection
        .transaction()
        .map_err(|_| "media_pack_transaction_failed".to_string())?;
    let existing_schema: Option<String> = transaction
        .query_row(
            "SELECT schema_version FROM knowledge_packs WHERE pack_id = ?1",
            [&pack.pack_id],
            |row| row.get(0),
        )
        .optional()
        .map_err(|_| "media_pack_read_failed".to_string())?;
    if existing_schema
        .as_deref()
        .is_some_and(|value| value != pack.schema_version)
    {
        return Err("media_pack_conflict".to_string());
    }
    transaction
        .execute(
            "INSERT OR IGNORE INTO knowledge_packs(pack_id, schema_version, loaded_at)
             VALUES (?1, ?2, unixepoch())",
            params![pack.pack_id, pack.schema_version],
        )
        .map_err(|_| "media_pack_write_failed".to_string())?;
    for title in &pack.titles {
        transaction
            .execute(
                "INSERT INTO media_titles(uuid, title, release_year, content_rating)
                 VALUES (?1, ?2, ?3, ?4)
                 ON CONFLICT(uuid) DO UPDATE SET uuid = excluded.uuid
                 WHERE media_titles.title = excluded.title
                   AND media_titles.release_year = excluded.release_year
                   AND media_titles.content_rating IS excluded.content_rating",
                params![
                    title.uuid,
                    title.title,
                    title.release_year,
                    title.content_rating
                ],
            )
            .map_err(|_| "media_title_write_failed".to_string())?;
        let matches: u32 = transaction
            .query_row(
                "SELECT COUNT(*) FROM media_titles
                 WHERE uuid = ?1 AND title = ?2 AND release_year = ?3
                   AND content_rating IS ?4",
                params![
                    title.uuid,
                    title.title,
                    title.release_year,
                    title.content_rating
                ],
                |row| row.get(0),
            )
            .map_err(|_| "media_title_verify_failed".to_string())?;
        if matches != 1 {
            return Err("media_title_conflict".to_string());
        }
        transaction
            .execute(
                "INSERT OR IGNORE INTO pack_title_owners(pack_id, title_uuid) VALUES (?1, ?2)",
                params![pack.pack_id, title.uuid],
            )
            .map_err(|_| "media_title_owner_write_failed".to_string())?;
    }
    for entity in &pack.entities {
        transaction
            .execute(
                "INSERT INTO media_entities(uuid, entity_type, name)
                 VALUES (?1, ?2, ?3)
                 ON CONFLICT(uuid) DO UPDATE SET uuid = excluded.uuid
                 WHERE media_entities.entity_type = excluded.entity_type
                   AND media_entities.name = excluded.name",
                params![entity.uuid, entity.entity_type, entity.name],
            )
            .map_err(|_| "media_entity_write_failed".to_string())?;
        let matches: u32 = transaction
            .query_row(
                "SELECT COUNT(*) FROM media_entities
                 WHERE uuid = ?1 AND entity_type = ?2 AND name = ?3",
                params![entity.uuid, entity.entity_type, entity.name],
                |row| row.get(0),
            )
            .map_err(|_| "media_entity_verify_failed".to_string())?;
        if matches != 1 {
            return Err("media_entity_conflict".to_string());
        }
        transaction
            .execute(
                "INSERT OR IGNORE INTO pack_entity_owners(pack_id, entity_uuid) VALUES (?1, ?2)",
                params![pack.pack_id, entity.uuid],
            )
            .map_err(|_| "media_entity_owner_write_failed".to_string())?;
    }
    for edge in &pack.edges {
        transaction
            .execute(
                "INSERT OR IGNORE INTO media_edges(title_uuid, entity_uuid) VALUES (?1, ?2)",
                params![edge.title_uuid, edge.entity_uuid],
            )
            .map_err(|_| "media_edge_write_failed".to_string())?;
        transaction
            .execute(
                "INSERT OR IGNORE INTO pack_edge_owners(pack_id, title_uuid, entity_uuid)
                 VALUES (?1, ?2, ?3)",
                params![pack.pack_id, edge.title_uuid, edge.entity_uuid],
            )
            .map_err(|_| "media_edge_owner_write_failed".to_string())?;
    }
    transaction
        .commit()
        .map_err(|_| "media_pack_commit_failed".to_string())
}

pub fn unload_relational_media_pack(path: String, pack_id: String) -> Result<bool, String> {
    let mut connection = Connection::open(path).map_err(|_| "database_open_failed".to_string())?;
    apply_migration(&mut connection)?;
    let transaction = connection
        .transaction()
        .map_err(|_| "media_pack_transaction_failed".to_string())?;
    let deleted = transaction
        .execute("DELETE FROM knowledge_packs WHERE pack_id = ?1", [&pack_id])
        .map_err(|_| "media_pack_delete_failed".to_string())?;
    if deleted > 0 {
        transaction
            .execute(
                "DELETE FROM media_edges
                 WHERE NOT EXISTS (
                   SELECT 1 FROM pack_edge_owners owner
                   WHERE owner.title_uuid = media_edges.title_uuid
                     AND owner.entity_uuid = media_edges.entity_uuid
                 )",
                [],
            )
            .map_err(|_| "media_edge_cleanup_failed".to_string())?;
        transaction
            .execute(
                "DELETE FROM media_titles
                 WHERE NOT EXISTS (
                   SELECT 1 FROM pack_title_owners owner
                   WHERE owner.title_uuid = media_titles.uuid
                 )",
                [],
            )
            .map_err(|_| "media_title_cleanup_failed".to_string())?;
        transaction
            .execute(
                "DELETE FROM media_entities
                 WHERE NOT EXISTS (
                   SELECT 1 FROM pack_entity_owners owner
                   WHERE owner.entity_uuid = media_entities.uuid
                 )",
                [],
            )
            .map_err(|_| "media_entity_cleanup_failed".to_string())?;
    }
    transaction
        .commit()
        .map_err(|_| "media_pack_commit_failed".to_string())?;
    Ok(deleted > 0)
}

pub fn query_relational_media_graph(
    path: String,
    query: RelationalMediaGraphQuery,
) -> Result<Vec<RelationalMediaTitle>, String> {
    if query.entity_type.is_some() != query.entity_name.is_some() {
        return Err("media_query_invalid".to_string());
    }
    let mut connection = Connection::open(path).map_err(|_| "database_open_failed".to_string())?;
    apply_migration(&mut connection)?;
    let mut statement = connection
        .prepare(
            "SELECT DISTINCT title.uuid, title.title, title.release_year, title.content_rating
             FROM media_titles title
             LEFT JOIN media_edges edge ON edge.title_uuid = title.uuid
             LEFT JOIN media_entities entity ON entity.uuid = edge.entity_uuid
             WHERE (?1 IS NULL OR (entity.entity_type = ?1 AND lower(entity.name) = lower(?2)))
               AND (?3 IS NULL OR title.release_year > ?3)
               AND (?4 IS NULL OR title.release_year < ?4)
               AND (?5 IS NULL OR title.content_rating = ?5)
             ORDER BY title.title, title.uuid",
        )
        .map_err(|_| "media_query_prepare_failed".to_string())?;
    let rows = statement
        .query_map(
            params![
                query.entity_type,
                query.entity_name,
                query.released_after,
                query.released_before,
                query.content_rating
            ],
            |row| {
                Ok(RelationalMediaTitle {
                    uuid: row.get(0)?,
                    title: row.get(1)?,
                    release_year: row.get(2)?,
                    content_rating: row.get(3)?,
                })
            },
        )
        .map_err(|_| "media_query_failed".to_string())?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|_| "media_query_decode_failed".to_string())?;
    Ok(rows)
}

fn validate_media_pack(pack: &RelationalMediaKnowledgePack) -> Result<(), String> {
    if pack.pack_id.trim().is_empty() || pack.schema_version != "1.0.0" {
        return Err("media_pack_invalid".to_string());
    }
    let title_ids = pack
        .titles
        .iter()
        .map(|row| row.uuid.as_str())
        .collect::<std::collections::HashSet<_>>();
    let entity_ids = pack
        .entities
        .iter()
        .map(|row| row.uuid.as_str())
        .collect::<std::collections::HashSet<_>>();
    if pack
        .titles
        .iter()
        .any(|row| row.uuid.trim().is_empty() || row.title.trim().is_empty())
        || pack.entities.iter().any(|row| {
            row.uuid.trim().is_empty()
                || row.name.trim().is_empty()
                || row.entity_type.trim().is_empty()
        })
        || pack.edges.iter().any(|edge| {
            !title_ids.contains(edge.title_uuid.as_str())
                || !entity_ids.contains(edge.entity_uuid.as_str())
        })
    {
        return Err("media_pack_invalid".to_string());
    }
    Ok(())
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
    apply_migration_sql(connection, MIGRATION_V1)
}

fn apply_migration_sql(
    connection: &mut Connection,
    migration: &str,
) -> Result<RelationalStoreStatus, String> {
    connection
        .pragma_update(None, "foreign_keys", "ON")
        .map_err(|_| "foreign_key_enable_failed".to_string())?;
    let transaction = connection
        .transaction()
        .map_err(|_| "migration_transaction_failed".to_string())?;
    transaction
        .execute_batch(migration)
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
    fn migration_failure_rolls_back_schema_and_version_atomically() {
        let mut connection = Connection::open_in_memory().unwrap();
        connection
            .execute("CREATE TABLE existing_marker(value TEXT NOT NULL)", [])
            .unwrap();
        let invalid =
            format!("{MIGRATION_V1}\nCREATE TABLE partial_write(value TEXT);\nTHIS IS NOT SQL;");

        assert!(apply_migration_sql(&mut connection, &invalid).is_err());
        let migration_table: u32 = connection
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master
                 WHERE type = 'table' AND name = 'schema_migrations'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        let partial_table: u32 = connection
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master
                 WHERE type = 'table' AND name = 'partial_write'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        let marker_table: u32 = connection
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master
                 WHERE type = 'table' AND name = 'existing_marker'",
                [],
                |row| row.get(0),
            )
            .unwrap();

        assert_eq!(migration_table, 0);
        assert_eq!(partial_table, 0);
        assert_eq!(marker_table, 1);
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
    fn media_pack_api_queries_and_preserves_shared_rows_until_last_unload() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("graph.sqlite");
        let shared_title = RelationalMediaTitle {
            uuid: "new".to_string(),
            title: "New Film".to_string(),
            release_year: 2020,
            content_rating: Some("PG".to_string()),
        };
        let shared_entity = RelationalMediaEntity {
            uuid: "actor-x".to_string(),
            entity_type: "actor".to_string(),
            name: "Actor X".to_string(),
        };
        let shared_edge = RelationalMediaEdge {
            title_uuid: shared_title.uuid.clone(),
            entity_uuid: shared_entity.uuid.clone(),
        };
        let pack = |id: &str| RelationalMediaKnowledgePack {
            pack_id: id.to_string(),
            schema_version: "1.0.0".to_string(),
            titles: vec![shared_title.clone()],
            entities: vec![shared_entity.clone()],
            edges: vec![shared_edge.clone()],
        };
        let database = path.to_string_lossy().into_owned();

        load_relational_media_pack(database.clone(), pack("movies")).unwrap();
        load_relational_media_pack(database.clone(), pack("awards")).unwrap();
        let result = query_relational_media_graph(
            database.clone(),
            RelationalMediaGraphQuery {
                entity_type: Some("actor".to_string()),
                entity_name: Some("actor x".to_string()),
                released_after: Some(2015),
                released_before: None,
                content_rating: Some("PG".to_string()),
            },
        )
        .unwrap();
        assert_eq!(result, vec![shared_title]);

        assert!(unload_relational_media_pack(database.clone(), "movies".to_string()).unwrap());
        assert_eq!(
            query_relational_media_graph(
                database.clone(),
                RelationalMediaGraphQuery {
                    entity_type: None,
                    entity_name: None,
                    released_after: None,
                    released_before: None,
                    content_rating: None,
                },
            )
            .unwrap()
            .len(),
            1
        );
        assert!(unload_relational_media_pack(database.clone(), "awards".to_string()).unwrap());
        assert!(query_relational_media_graph(
            database,
            RelationalMediaGraphQuery {
                entity_type: None,
                entity_name: None,
                released_after: None,
                released_before: None,
                content_rating: None,
            },
        )
        .unwrap()
        .is_empty());
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
