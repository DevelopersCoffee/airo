use std::fs::{self, File, OpenOptions};
use std::io::{BufWriter, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use memmap2::{Mmap, MmapOptions};
use rusqlite::{params, params_from_iter, types::Value, Connection, OptionalExtension, Statement};

use super::m3u::{for_each_m3u_channel_bytes, M3uChannel, M3uParseStats};

const CACHE_MAGIC: &[u8; 8] = b"AIROPLV2";
const CACHE_VERSION: u32 = 2;
const SQLITE_SCHEMA_VERSION: u32 = 2;
const CACHE_FILE_NAME: &str = "playlist-v2.cache";
const INDEX_FILE_NAME: &str = "playlist-v2.sqlite";
const CACHE_TEMP_FILE_NAME: &str = "playlist-v2.cache.tmp";
const INDEX_TEMP_FILE_NAME: &str = "playlist-v2.sqlite.tmp";
const CACHE_HEADER_LEN: usize = 8 + 4 + 8 + 16 + 8;
const DEFAULT_PAGE_LIMIT: u32 = 50;
const MAX_PAGE_LIMIT: u32 = 500;
const INSERT_CHANNEL_SQL: &str = "
    INSERT INTO channels(
      normalized_name, name, url, logo, channel_group, tvg_id,
      tvg_name, language, aliases, country, provider, tags, normalized_aliases,
      normalized_genre, normalized_language, normalized_country,
      normalized_provider, normalized_tags, search_text
    ) VALUES (
      ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14,
      ?15, ?16, ?17, ?18, ?19
    )
    ON CONFLICT(normalized_name) DO UPDATE SET
      name = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.name ELSE channels.name END,
      url = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.url ELSE channels.url END,
      logo = COALESCE(channels.logo, excluded.logo),
      channel_group = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.channel_group ELSE channels.channel_group END,
      tvg_id = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.tvg_id ELSE channels.tvg_id END,
      tvg_name = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.tvg_name ELSE channels.tvg_name END,
      language = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.language ELSE channels.language END,
      aliases = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.aliases ELSE channels.aliases END,
      country = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.country ELSE channels.country END,
      provider = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.provider ELSE channels.provider END,
      tags = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.tags ELSE channels.tags END,
      normalized_aliases = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.normalized_aliases ELSE channels.normalized_aliases END,
      normalized_genre = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.normalized_genre ELSE channels.normalized_genre END,
      normalized_language = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.normalized_language ELSE channels.normalized_language END,
      normalized_country = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.normalized_country ELSE channels.normalized_country END,
      normalized_provider = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.normalized_provider ELSE channels.normalized_provider END,
      normalized_tags = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.normalized_tags ELSE channels.normalized_tags END,
      search_text = CASE
        WHEN channels.logo IS NULL AND excluded.logo IS NOT NULL
        THEN excluded.search_text ELSE channels.search_text END";

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PlaylistCacheStatus {
    ColdBuilt,
    WarmOpened,
    IndexRebuiltFromCache,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PlaylistEngineErrorCode {
    InvalidArgument,
    Io,
    InvalidCache,
    Database,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PlaylistEngineError {
    pub code: PlaylistEngineErrorCode,
    pub message: String,
}

impl std::fmt::Display for PlaylistEngineError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(&self.message)
    }
}

impl std::error::Error for PlaylistEngineError {}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PlaylistIndexDescriptor {
    pub index_path: String,
    pub cache_path: String,
    pub total_channels: u32,
    pub source_size_bytes: u64,
    pub source_modified_nanos: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct M3uChannelPage {
    pub channels: Vec<M3uChannel>,
    pub offset: u32,
    pub total: u32,
    pub has_more: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PlaylistSearchField {
    Title,
    Alias,
    Genre,
    Language,
    Country,
    Provider,
    Tag,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PlaylistSearchOperator {
    Equals,
    Prefix,
    Contains,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PlaylistSearchFilter {
    pub field: PlaylistSearchField,
    pub operator: PlaylistSearchOperator,
    pub value: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PlaylistOpenTimings {
    pub total_micros: u64,
    pub source_map_micros: u64,
    pub index_build_micros: u64,
    pub first_page_micros: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PlaylistIndexOpenResult {
    pub descriptor: PlaylistIndexDescriptor,
    pub first_page: M3uChannelPage,
    pub parse_stats: M3uParseStats,
    pub cache_status: PlaylistCacheStatus,
    pub timings: PlaylistOpenTimings,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct SourceFingerprint {
    size: u64,
    modified_nanos: u64,
}

/// Open a versioned local playlist index and return its first page.
///
/// Existing #814 parser APIs remain unchanged. This API is path-based so raw
/// playlist content is never copied across FRB or the Dart main isolate.
pub fn open_playlist_index(
    source_path: String,
    cache_directory: String,
    first_page_limit: u32,
) -> Result<PlaylistIndexOpenResult, PlaylistEngineError> {
    let total_started = Instant::now();
    let source = validate_file_path(&source_path, "source_path")?;
    let cache_dir = validate_directory_path(&cache_directory)?;
    fs::create_dir_all(&cache_dir).map_err(io_error)?;

    let fingerprint = source_fingerprint(&source)?;
    let cache_path = cache_dir.join(CACHE_FILE_NAME);
    let index_path = cache_dir.join(INDEX_FILE_NAME);
    cleanup_temporary_artifacts(&cache_dir);

    let requested_limit = normalize_limit(first_page_limit)?;
    let mut source_map_micros = 0;
    let mut index_build_micros = 0;
    let parse_stats;
    let cache_status;

    if cache_matches(&cache_path, fingerprint) {
        if index_matches(&index_path, fingerprint)? {
            parse_stats = M3uParseStats::default();
            cache_status = PlaylistCacheStatus::WarmOpened;
        } else {
            let build_started = Instant::now();
            rebuild_index_from_cache(&cache_path, &index_path, fingerprint)?;
            index_build_micros = elapsed_micros(build_started);
            parse_stats = M3uParseStats::default();
            cache_status = PlaylistCacheStatus::IndexRebuiltFromCache;
        }
    } else {
        let map_started = Instant::now();
        let source_file = File::open(&source).map_err(io_error)?;
        // SAFETY: `source_file` remains alive for the map creation, the map is
        // read-only, and this function never mutates or truncates the caller's
        // source file. External mutation is the caller's responsibility, just
        // as with any file-backed read.
        let source_map = unsafe { MmapOptions::new().map(&source_file) }.map_err(io_error)?;
        source_map_micros = elapsed_micros(map_started);

        let build_started = Instant::now();
        parse_stats = build_cache_and_index(&source_map, &cache_path, &index_path, fingerprint)?;
        index_build_micros = elapsed_micros(build_started);
        cache_status = PlaylistCacheStatus::ColdBuilt;
    }

    let first_page_started = Instant::now();
    let first_page = read_page(&index_path, 0, requested_limit, None)?;
    let first_page_micros = elapsed_micros(first_page_started);
    let descriptor = descriptor_for(&index_path, &cache_path, fingerprint, first_page.total);

    Ok(PlaylistIndexOpenResult {
        descriptor,
        first_page,
        parse_stats,
        cache_status,
        timings: PlaylistOpenTimings {
            total_micros: elapsed_micros(total_started),
            source_map_micros,
            index_build_micros,
            first_page_micros,
        },
    })
}

/// Read a stable zero-based page without materializing the full playlist.
pub fn page_playlist_index(
    index_path: String,
    offset: u32,
    limit: u32,
) -> Result<M3uChannelPage, PlaylistEngineError> {
    let path = validate_file_path(&index_path, "index_path")?;
    read_page(&path, offset, normalize_limit(limit)?, None)
}

/// Search indexed channel fields and return a bounded stable page.
pub fn search_playlist_index(
    index_path: String,
    query: String,
    offset: u32,
    limit: u32,
) -> Result<M3uChannelPage, PlaylistEngineError> {
    let path = validate_file_path(&index_path, "index_path")?;
    let normalized_query = normalize_search(&query);
    if normalized_query.is_empty() {
        return Err(invalid_argument("query must not be empty"));
    }
    read_page(
        &path,
        offset,
        normalize_limit(limit)?,
        Some(normalized_query),
    )
}

/// Search text and/or structured fields through one deterministic native API.
///
/// Text ranking is exact title, title prefix, alias exact/prefix, field
/// substring, then bounded trigram fuzzy matching. Structured filters use AND
/// semantics and may be supplied without text for IntentCommand execution.
pub fn search_playlist_index_v2(
    index_path: String,
    query: Option<String>,
    filters: Vec<PlaylistSearchFilter>,
    offset: u32,
    limit: u32,
) -> Result<M3uChannelPage, PlaylistEngineError> {
    let path = validate_file_path(&index_path, "index_path")?;
    let query = query
        .as_deref()
        .map(normalize_search)
        .filter(|value| !value.is_empty());
    let filters = normalize_filters(filters)?;
    if query.is_none() && filters.is_empty() {
        return Err(invalid_argument("query or filters must be provided"));
    }
    read_ranked_page(
        &path,
        query.as_deref(),
        &filters,
        offset,
        normalize_limit(limit)?,
    )
}

fn build_cache_and_index(
    source: &[u8],
    cache_path: &Path,
    index_path: &Path,
    fingerprint: SourceFingerprint,
) -> Result<M3uParseStats, PlaylistEngineError> {
    let cache_temp = sibling(cache_path, CACHE_TEMP_FILE_NAME);
    let index_temp = sibling(index_path, INDEX_TEMP_FILE_NAME);
    remove_if_exists(&cache_temp);
    remove_if_exists(&index_temp);

    let result = (|| {
        let cache_file = OpenOptions::new()
            .create_new(true)
            .read(true)
            .write(true)
            .open(&cache_temp)
            .map_err(io_error)?;
        let mut cache_writer = BufWriter::with_capacity(1024 * 1024, cache_file);
        write_cache_header(&mut cache_writer, fingerprint, 0)?;

        let mut connection = create_index(&index_temp, fingerprint)?;
        let transaction = connection.transaction().map_err(database_error)?;
        let mut insert_statement = transaction
            .prepare_cached(INSERT_CHANNEL_SQL)
            .map_err(database_error)?;
        let mut cached_count = 0_u64;
        let stats = for_each_m3u_channel_bytes(source, |channel| {
            write_cache_channel(&mut cache_writer, &channel)
                .map_err(|error| error.message.clone())?;
            insert_channel(&mut insert_statement, &channel)
                .map_err(|error| error.message.clone())?;
            cached_count = cached_count.saturating_add(1);
            Ok(())
        })
        .map_err(|message| PlaylistEngineError {
            code: PlaylistEngineErrorCode::Database,
            message,
        })?;

        drop(insert_statement);
        transaction.commit().map_err(database_error)?;
        finalize_index(&connection)?;
        drop(connection);

        cache_writer.flush().map_err(io_error)?;
        cache_writer
            .seek(SeekFrom::Start((8 + 4 + 8 + 16) as u64))
            .map_err(io_error)?;
        cache_writer
            .write_all(&cached_count.to_le_bytes())
            .map_err(io_error)?;
        cache_writer.flush().map_err(io_error)?;
        cache_writer.get_ref().sync_all().map_err(io_error)?;
        drop(cache_writer);

        replace_atomically(&cache_temp, cache_path)?;
        replace_atomically(&index_temp, index_path)?;
        Ok(stats)
    })();

    if result.is_err() {
        remove_if_exists(&cache_temp);
        remove_if_exists(&index_temp);
    }
    result
}

fn rebuild_index_from_cache(
    cache_path: &Path,
    index_path: &Path,
    fingerprint: SourceFingerprint,
) -> Result<(), PlaylistEngineError> {
    let mapped = MappedPlaylistCache::open(cache_path, fingerprint)?;
    let index_temp = sibling(index_path, INDEX_TEMP_FILE_NAME);
    remove_if_exists(&index_temp);
    let result = (|| {
        let mut connection = create_index(&index_temp, fingerprint)?;
        let transaction = connection.transaction().map_err(database_error)?;
        let mut insert_statement = transaction
            .prepare_cached(INSERT_CHANNEL_SQL)
            .map_err(database_error)?;
        mapped.for_each_channel(|channel| insert_channel(&mut insert_statement, &channel))?;
        drop(insert_statement);
        transaction.commit().map_err(database_error)?;
        finalize_index(&connection)?;
        drop(connection);
        replace_atomically(&index_temp, index_path)
    })();
    if result.is_err() {
        remove_if_exists(&index_temp);
    }
    result
}

fn create_index(
    path: &Path,
    fingerprint: SourceFingerprint,
) -> Result<Connection, PlaylistEngineError> {
    let connection = Connection::open(path).map_err(database_error)?;
    connection
        .execute_batch(
            "PRAGMA journal_mode=OFF;
             PRAGMA synchronous=OFF;
             PRAGMA temp_store=MEMORY;
             PRAGMA locking_mode=EXCLUSIVE;
             PRAGMA cache_size=-32768;
             PRAGMA page_size=16384;
             PRAGMA threads=4;
             CREATE TABLE metadata (
               schema_version INTEGER NOT NULL,
               source_size INTEGER NOT NULL,
               source_modified_nanos INTEGER NOT NULL
             );
             CREATE TABLE channels (
               position INTEGER PRIMARY KEY AUTOINCREMENT,
               normalized_name TEXT NOT NULL UNIQUE,
               name TEXT NOT NULL,
               url TEXT NOT NULL,
               logo TEXT,
               channel_group TEXT,
               tvg_id TEXT,
               tvg_name TEXT,
               language TEXT,
               aliases TEXT NOT NULL,
               normalized_aliases TEXT NOT NULL,
               country TEXT,
               provider TEXT,
               tags TEXT NOT NULL,
               normalized_genre TEXT,
               normalized_language TEXT,
               normalized_country TEXT,
               normalized_provider TEXT,
               normalized_tags TEXT NOT NULL,
               search_text TEXT NOT NULL
             );",
        )
        .map_err(database_error)?;
    connection
        .execute(
            "INSERT INTO metadata(schema_version, source_size, source_modified_nanos)
             VALUES (?1, ?2, ?3)",
            params![
                SQLITE_SCHEMA_VERSION,
                to_sql_i64(fingerprint.size)?,
                to_sql_i64(fingerprint.modified_nanos)?,
            ],
        )
        .map_err(database_error)?;
    Ok(connection)
}

fn insert_channel(
    statement: &mut Statement<'_>,
    channel: &M3uChannel,
) -> Result<(), PlaylistEngineError> {
    let normalized_name = normalize_identity(&channel.name);
    statement
        .execute(params![
            normalized_name,
            channel.name,
            channel.url,
            channel.logo,
            channel.group,
            channel.tvg_id,
            channel.tvg_name,
            channel.language,
            encode_list(&channel.aliases),
            channel.country,
            channel.provider,
            encode_list(&channel.tags),
            normalize_list(&channel.aliases),
            normalize_optional(channel.group.as_deref()),
            normalize_optional(channel.language.as_deref()),
            normalize_optional(channel.country.as_deref()),
            normalize_optional(channel.provider.as_deref()),
            normalize_list(&channel.tags),
            channel_search_text(channel),
        ])
        .map_err(database_error)?;
    Ok(())
}

fn finalize_index(connection: &Connection) -> Result<(), PlaylistEngineError> {
    connection
        .execute_batch(
            "CREATE INDEX channels_genre_idx ON channels(normalized_genre);
             CREATE INDEX channels_language_idx ON channels(normalized_language);
             CREATE INDEX channels_country_idx ON channels(normalized_country);
             CREATE INDEX channels_provider_idx ON channels(normalized_provider);
             CREATE INDEX channels_aliases_idx ON channels(normalized_aliases);
             CREATE INDEX channels_tags_idx ON channels(normalized_tags);
             PRAGMA optimize;",
        )
        .map_err(database_error)
}

fn read_page(
    index_path: &Path,
    offset: u32,
    limit: u32,
    query: Option<String>,
) -> Result<M3uChannelPage, PlaylistEngineError> {
    let connection =
        Connection::open_with_flags(index_path, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY)
            .map_err(database_error)?;
    let pattern = query.as_ref().map(|value| format!("%{value}%"));
    let total: u32 = if let Some(pattern) = pattern.as_ref() {
        connection
            .query_row(
                "SELECT COUNT(*) FROM channels WHERE search_text LIKE ?1",
                [pattern],
                |row| row.get(0),
            )
            .map_err(database_error)?
    } else {
        connection
            .query_row("SELECT COUNT(*) FROM channels", [], |row| row.get(0))
            .map_err(database_error)?
    };

    let sql = if pattern.is_some() {
        "SELECT name, url, logo, channel_group, tvg_id, tvg_name, language,
                aliases, country, provider, tags
         FROM channels WHERE search_text LIKE ?1
         ORDER BY position LIMIT ?2 OFFSET ?3"
    } else {
        "SELECT name, url, logo, channel_group, tvg_id, tvg_name, language,
                aliases, country, provider, tags
         FROM channels ORDER BY position LIMIT ?2 OFFSET ?3"
    };
    let mut statement = connection.prepare(sql).map_err(database_error)?;
    let channels = if let Some(pattern) = pattern {
        statement
            .query_map(params![pattern, limit, offset], row_to_channel)
            .map_err(database_error)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(database_error)?
    } else {
        statement
            .query_map(
                params![Option::<String>::None, limit, offset],
                row_to_channel,
            )
            .map_err(database_error)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(database_error)?
    };
    let returned = channels.len().try_into().unwrap_or(u32::MAX);
    Ok(M3uChannelPage {
        channels,
        offset,
        total,
        has_more: offset.saturating_add(returned) < total,
    })
}

fn normalize_filters(
    filters: Vec<PlaylistSearchFilter>,
) -> Result<Vec<PlaylistSearchFilter>, PlaylistEngineError> {
    filters
        .into_iter()
        .map(|filter| {
            let value = normalize_search(&filter.value);
            if value.is_empty() {
                return Err(invalid_argument("search filter value must not be empty"));
            }
            Ok(PlaylistSearchFilter { value, ..filter })
        })
        .collect()
}

fn read_ranked_page(
    index_path: &Path,
    query: Option<&str>,
    filters: &[PlaylistSearchFilter],
    offset: u32,
    limit: u32,
) -> Result<M3uChannelPage, PlaylistEngineError> {
    let connection =
        Connection::open_with_flags(index_path, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY)
            .map_err(database_error)?;
    connection
        .execute_batch("PRAGMA case_sensitive_like=ON; PRAGMA query_only=ON;")
        .map_err(database_error)?;
    let (filter_sql, filter_values) = filter_sql(filters);
    let (source_sql, mut values) = match query {
        Some(query) => {
            let identity = normalize_identity(query);
            let identity_prefix = format!("{identity}*");
            let prefix = format!("{query}*");
            let candidate_sql = "
              SELECT position, 0 AS rank FROM channels WHERE normalized_name = ?
              UNION ALL
              SELECT position, 10 FROM channels WHERE normalized_name GLOB ?
              UNION ALL
              SELECT position, 20 FROM channels WHERE normalized_aliases = ?
              UNION ALL
              SELECT position, 30 FROM channels WHERE normalized_aliases GLOB ?
              UNION ALL
              SELECT position, 40 FROM channels WHERE normalized_genre = ?
              UNION ALL
              SELECT position, 50 FROM channels WHERE normalized_genre GLOB ?
              UNION ALL
              SELECT position, 40 FROM channels WHERE normalized_language = ?
              UNION ALL
              SELECT position, 50 FROM channels WHERE normalized_language GLOB ?
              UNION ALL
              SELECT position, 40 FROM channels WHERE normalized_country = ?
              UNION ALL
              SELECT position, 50 FROM channels WHERE normalized_country GLOB ?
              UNION ALL
              SELECT position, 40 FROM channels WHERE normalized_provider = ?
              UNION ALL
              SELECT position, 50 FROM channels WHERE normalized_provider GLOB ?
              UNION ALL
              SELECT position, 40 FROM channels WHERE normalized_tags = ?
              UNION ALL
              SELECT position, 50 FROM channels WHERE normalized_tags GLOB ?";
            let values = vec![
                Value::Text(identity.clone()),
                Value::Text(identity_prefix),
                Value::Text(query.to_string()),
                Value::Text(prefix.clone()),
                Value::Text(query.to_string()),
                Value::Text(prefix.clone()),
                Value::Text(query.to_string()),
                Value::Text(prefix.clone()),
                Value::Text(query.to_string()),
                Value::Text(prefix.clone()),
                Value::Text(query.to_string()),
                Value::Text(prefix.clone()),
                Value::Text(query.to_string()),
                Value::Text(prefix),
            ];
            (
                format!(
                    "WITH candidates AS ({candidate_sql}),
                     ranked AS (
                       SELECT position, MIN(rank) AS rank
                       FROM candidates GROUP BY position
                     )
                     SELECT c.name, c.url, c.logo, c.channel_group, c.tvg_id,
                            c.tvg_name, c.language, c.aliases, c.country,
                            c.provider, c.tags, r.rank, c.position
                     FROM ranked r JOIN channels c ON c.position = r.position
                     WHERE 1 = 1{filter_sql}"
                ),
                values,
            )
        }
        None => (
            format!(
                "SELECT name, url, logo, channel_group, tvg_id, tvg_name,
                        language, aliases, country, provider, tags,
                        0 AS rank, position
                 FROM channels WHERE 1 = 1{filter_sql}"
            ),
            Vec::new(),
        ),
    };
    values.extend(filter_values);
    let count_sql = format!("SELECT COUNT(*) FROM ({source_sql})");
    let total: u32 = connection
        .query_row(&count_sql, params_from_iter(values.iter()), |row| {
            row.get(0)
        })
        .map_err(database_error)?;
    if total == 0 {
        if let Some(query) = query {
            return read_fuzzy_page(&connection, query, filters, offset, limit);
        }
    }
    values.extend([
        Value::Integer(i64::from(limit)),
        Value::Integer(i64::from(offset)),
    ]);
    let sql = format!(
        "SELECT name, url, logo, channel_group, tvg_id, tvg_name, language,
                aliases, country, provider, tags
         FROM ({source_sql}) ORDER BY rank, position LIMIT ? OFFSET ?"
    );
    let mut statement = connection.prepare(&sql).map_err(database_error)?;
    let channels = statement
        .query_map(params_from_iter(values.iter()), row_to_channel)
        .map_err(database_error)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(database_error)?;
    page_from_channels(channels, offset, total)
}

fn filter_sql(filters: &[PlaylistSearchFilter]) -> (String, Vec<Value>) {
    let mut sql = String::new();
    let mut values = Vec::new();
    for filter in filters {
        let (column, list) = match filter.field {
            PlaylistSearchField::Title => ("normalized_name", false),
            PlaylistSearchField::Alias => ("normalized_aliases", true),
            PlaylistSearchField::Genre => ("normalized_genre", false),
            PlaylistSearchField::Language => ("normalized_language", false),
            PlaylistSearchField::Country => ("normalized_country", false),
            PlaylistSearchField::Provider => ("normalized_provider", false),
            PlaylistSearchField::Tag => ("normalized_tags", true),
        };
        sql.push_str(" AND ");
        match (filter.operator, list) {
            (PlaylistSearchOperator::Equals, true) => {
                sql.push_str(&format!(
                    "instr(char(31) || {column} || char(31),
                           char(31) || ? || char(31)) > 0"
                ));
                values.push(Value::Text(filter.value.clone()));
            }
            (PlaylistSearchOperator::Equals, false) => {
                sql.push_str(&format!("{column} = ?"));
                values.push(Value::Text(filter.value.clone()));
            }
            (PlaylistSearchOperator::Prefix, true) => {
                sql.push_str(&format!("({column} LIKE ? OR {column} LIKE ?)"));
                values.push(Value::Text(format!("{}%", filter.value)));
                values.push(Value::Text(format!("%{LIST_SEPARATOR}{}%", filter.value)));
            }
            (PlaylistSearchOperator::Prefix, false) => {
                sql.push_str(&format!("{column} LIKE ?"));
                values.push(Value::Text(format!("{}%", filter.value)));
            }
            (PlaylistSearchOperator::Contains, _) => {
                sql.push_str(&format!("{column} LIKE ?"));
                values.push(Value::Text(format!("%{}%", filter.value)));
            }
        }
    }
    (sql, values)
}

fn page_from_channels(
    channels: Vec<M3uChannel>,
    offset: u32,
    total: u32,
) -> Result<M3uChannelPage, PlaylistEngineError> {
    let returned = channels.len().try_into().unwrap_or(u32::MAX);
    Ok(M3uChannelPage {
        channels,
        offset,
        total,
        has_more: offset.saturating_add(returned) < total,
    })
}

fn read_fuzzy_page(
    connection: &Connection,
    query: &str,
    filters: &[PlaylistSearchFilter],
    offset: u32,
    limit: u32,
) -> Result<M3uChannelPage, PlaylistEngineError> {
    let identity = normalize_identity(query);
    let candidate_prefix = identity.chars().take(3).collect::<String>();
    if candidate_prefix.len() < 2 {
        return page_from_channels(Vec::new(), offset, 0);
    }
    let (filter_sql, filter_values) = filter_sql(filters);
    let qualified_filters = filter_sql
        .replace("normalized_name", "c.normalized_name")
        .replace("normalized_aliases", "c.normalized_aliases")
        .replace("normalized_genre", "c.normalized_genre")
        .replace("normalized_language", "c.normalized_language")
        .replace("normalized_country", "c.normalized_country")
        .replace("normalized_provider", "c.normalized_provider")
        .replace("normalized_tags", "c.normalized_tags");
    let sql = format!(
        "SELECT c.name, c.url, c.logo, c.channel_group, c.tvg_id,
                c.tvg_name, c.language, c.aliases, c.country, c.provider,
                c.tags, c.normalized_name, c.normalized_aliases, c.position
         FROM channels c
         WHERE (c.normalized_name GLOB ? OR c.normalized_aliases GLOB ?)
               {qualified_filters}
         ORDER BY c.position
         LIMIT 10000"
    );
    let mut values = vec![
        Value::Text(format!("{candidate_prefix}*")),
        Value::Text(format!("{candidate_prefix}*")),
    ];
    values.extend(filter_values);
    let mut statement = connection.prepare(&sql).map_err(database_error)?;
    let mut candidates = statement
        .query_map(params_from_iter(values.iter()), |row| {
            let channel = M3uChannel {
                name: row.get(0)?,
                url: row.get(1)?,
                logo: row.get(2)?,
                group: row.get(3)?,
                tvg_id: row.get(4)?,
                tvg_name: row.get(5)?,
                language: row.get(6)?,
                aliases: decode_list(row.get::<_, String>(7)?),
                country: row.get(8)?,
                provider: row.get(9)?,
                tags: decode_list(row.get::<_, String>(10)?),
            };
            Ok((
                channel,
                row.get::<_, String>(11)?,
                decode_list(row.get::<_, String>(12)?),
                row.get::<_, u32>(13)?,
            ))
        })
        .map_err(database_error)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(database_error)?;
    let maximum_distance = (identity.chars().count() / 4).clamp(1, 3);
    let mut ranked = candidates
        .drain(..)
        .filter_map(|(channel, title, aliases, position)| {
            let distance = std::iter::once(title.as_str())
                .chain(aliases.iter().map(String::as_str))
                .map(|candidate| levenshtein(&identity, &normalize_identity(candidate)))
                .min()
                .unwrap_or(usize::MAX);
            (distance <= maximum_distance).then_some((distance, position, channel))
        })
        .collect::<Vec<_>>();
    ranked.sort_by_key(|(distance, position, _)| (*distance, *position));
    let total = ranked.len().try_into().unwrap_or(u32::MAX);
    let start: usize = offset.try_into().unwrap_or(usize::MAX).min(ranked.len());
    let end = start
        .saturating_add(limit.try_into().unwrap_or(usize::MAX))
        .min(ranked.len());
    let channels = ranked
        .drain(start..end)
        .map(|(_, _, channel)| channel)
        .collect();
    page_from_channels(channels, offset, total)
}

fn levenshtein(left: &str, right: &str) -> usize {
    let right = right.chars().collect::<Vec<_>>();
    let mut previous = (0..=right.len()).collect::<Vec<_>>();
    let mut current = vec![0; right.len() + 1];
    for (left_index, left_character) in left.chars().enumerate() {
        current[0] = left_index + 1;
        for (right_index, right_character) in right.iter().enumerate() {
            current[right_index + 1] = (previous[right_index + 1] + 1)
                .min(current[right_index] + 1)
                .min(previous[right_index] + usize::from(left_character != *right_character));
        }
        std::mem::swap(&mut previous, &mut current);
    }
    previous[right.len()]
}

fn row_to_channel(row: &rusqlite::Row<'_>) -> rusqlite::Result<M3uChannel> {
    Ok(M3uChannel {
        name: row.get(0)?,
        url: row.get(1)?,
        logo: row.get(2)?,
        group: row.get(3)?,
        tvg_id: row.get(4)?,
        tvg_name: row.get(5)?,
        language: row.get(6)?,
        aliases: decode_list(row.get::<_, String>(7)?),
        country: row.get(8)?,
        provider: row.get(9)?,
        tags: decode_list(row.get::<_, String>(10)?),
    })
}

fn index_matches(path: &Path, fingerprint: SourceFingerprint) -> Result<bool, PlaylistEngineError> {
    if !path.is_file() {
        return Ok(false);
    }
    let connection =
        match Connection::open_with_flags(path, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY) {
            Ok(connection) => connection,
            Err(_) => return Ok(false),
        };
    let metadata = connection
        .query_row(
            "SELECT schema_version, source_size, source_modified_nanos
             FROM metadata LIMIT 1",
            [],
            |row| {
                Ok((
                    row.get::<_, u32>(0)?,
                    row.get::<_, u64>(1)?,
                    row.get::<_, u64>(2)?,
                ))
            },
        )
        .optional();
    match metadata {
        Ok(Some((version, size, modified))) => Ok(version == SQLITE_SCHEMA_VERSION
            && size == fingerprint.size
            && modified == fingerprint.modified_nanos),
        Ok(None) | Err(_) => Ok(false),
    }
}

fn cache_matches(path: &Path, fingerprint: SourceFingerprint) -> bool {
    MappedPlaylistCache::open(path, fingerprint).is_ok()
}

struct MappedPlaylistCache {
    map: Mmap,
    channel_count: u64,
}

impl MappedPlaylistCache {
    fn open(path: &Path, expected: SourceFingerprint) -> Result<Self, PlaylistEngineError> {
        let file = File::open(path).map_err(io_error)?;
        // SAFETY: the derived cache is immutable while mapped. Writers always
        // build a sibling temp file and atomically rename only after all maps
        // from earlier calls have been dropped.
        let map = unsafe { MmapOptions::new().map(&file) }.map_err(io_error)?;
        if map.len() < CACHE_HEADER_LEN || &map[..8] != CACHE_MAGIC {
            return Err(invalid_cache("playlist cache header is invalid"));
        }
        let version = read_u32(&map, 8)?;
        let source_size = read_u64(&map, 12)?;
        let modified_nanos = read_u128(&map, 20)?;
        let channel_count = read_u64(&map, 36)?;
        if version != CACHE_VERSION
            || source_size != expected.size
            || modified_nanos != u128::from(expected.modified_nanos)
        {
            return Err(invalid_cache("playlist cache is stale or incompatible"));
        }
        Ok(Self { map, channel_count })
    }

    fn for_each_channel<F>(&self, mut on_channel: F) -> Result<(), PlaylistEngineError>
    where
        F: FnMut(M3uChannel) -> Result<(), PlaylistEngineError>,
    {
        let mut offset = CACHE_HEADER_LEN;
        for _ in 0..self.channel_count {
            on_channel(read_cache_channel(&self.map, &mut offset)?)?;
        }
        if offset != self.map.len() {
            return Err(invalid_cache("playlist cache has trailing bytes"));
        }
        Ok(())
    }
}

fn write_cache_header<W: Write>(
    writer: &mut W,
    fingerprint: SourceFingerprint,
    channel_count: u64,
) -> Result<(), PlaylistEngineError> {
    writer.write_all(CACHE_MAGIC).map_err(io_error)?;
    writer
        .write_all(&CACHE_VERSION.to_le_bytes())
        .map_err(io_error)?;
    writer
        .write_all(&fingerprint.size.to_le_bytes())
        .map_err(io_error)?;
    writer
        .write_all(&u128::from(fingerprint.modified_nanos).to_le_bytes())
        .map_err(io_error)?;
    writer
        .write_all(&channel_count.to_le_bytes())
        .map_err(io_error)
}

fn write_cache_channel<W: Write>(
    writer: &mut W,
    channel: &M3uChannel,
) -> Result<(), PlaylistEngineError> {
    write_required_string(writer, &channel.name)?;
    write_required_string(writer, &channel.url)?;
    write_optional_string(writer, channel.logo.as_deref())?;
    write_optional_string(writer, channel.group.as_deref())?;
    write_optional_string(writer, channel.tvg_id.as_deref())?;
    write_optional_string(writer, channel.tvg_name.as_deref())?;
    write_optional_string(writer, channel.language.as_deref())?;
    write_string_list(writer, &channel.aliases)?;
    write_optional_string(writer, channel.country.as_deref())?;
    write_optional_string(writer, channel.provider.as_deref())?;
    write_string_list(writer, &channel.tags)
}

fn read_cache_channel(bytes: &[u8], offset: &mut usize) -> Result<M3uChannel, PlaylistEngineError> {
    Ok(M3uChannel {
        name: read_required_string(bytes, offset)?,
        url: read_required_string(bytes, offset)?,
        logo: read_optional_string(bytes, offset)?,
        group: read_optional_string(bytes, offset)?,
        tvg_id: read_optional_string(bytes, offset)?,
        tvg_name: read_optional_string(bytes, offset)?,
        language: read_optional_string(bytes, offset)?,
        aliases: read_string_list(bytes, offset)?,
        country: read_optional_string(bytes, offset)?,
        provider: read_optional_string(bytes, offset)?,
        tags: read_string_list(bytes, offset)?,
    })
}

fn write_required_string<W: Write>(writer: &mut W, value: &str) -> Result<(), PlaylistEngineError> {
    let length: u32 = value
        .len()
        .try_into()
        .map_err(|_| invalid_argument("playlist field exceeds cache limit"))?;
    writer.write_all(&length.to_le_bytes()).map_err(io_error)?;
    writer.write_all(value.as_bytes()).map_err(io_error)
}

fn write_optional_string<W: Write>(
    writer: &mut W,
    value: Option<&str>,
) -> Result<(), PlaylistEngineError> {
    match value {
        Some(value) => write_required_string(writer, value),
        None => writer.write_all(&u32::MAX.to_le_bytes()).map_err(io_error),
    }
}

fn write_string_list<W: Write>(
    writer: &mut W,
    values: &[String],
) -> Result<(), PlaylistEngineError> {
    let count: u32 = values
        .len()
        .try_into()
        .map_err(|_| invalid_argument("playlist list exceeds cache limit"))?;
    writer.write_all(&count.to_le_bytes()).map_err(io_error)?;
    for value in values {
        write_required_string(writer, value)?;
    }
    Ok(())
}

fn read_required_string(bytes: &[u8], offset: &mut usize) -> Result<String, PlaylistEngineError> {
    let length = read_u32(bytes, *offset)?;
    *offset = offset
        .checked_add(4)
        .ok_or_else(|| invalid_cache("playlist cache offset overflow"))?;
    if length == u32::MAX {
        return Err(invalid_cache("required cache field is null"));
    }
    read_string_body(bytes, offset, length)
}

fn read_optional_string(
    bytes: &[u8],
    offset: &mut usize,
) -> Result<Option<String>, PlaylistEngineError> {
    let length = read_u32(bytes, *offset)?;
    *offset = offset
        .checked_add(4)
        .ok_or_else(|| invalid_cache("playlist cache offset overflow"))?;
    if length == u32::MAX {
        return Ok(None);
    }
    read_string_body(bytes, offset, length).map(Some)
}

fn read_string_list(bytes: &[u8], offset: &mut usize) -> Result<Vec<String>, PlaylistEngineError> {
    let count = read_u32(bytes, *offset)?;
    *offset = offset
        .checked_add(4)
        .ok_or_else(|| invalid_cache("playlist cache offset overflow"))?;
    let capacity: usize = count
        .try_into()
        .map_err(|_| invalid_cache("playlist cache list is too large"))?;
    let mut values = Vec::with_capacity(capacity);
    for _ in 0..count {
        values.push(read_required_string(bytes, offset)?);
    }
    Ok(values)
}

fn read_string_body(
    bytes: &[u8],
    offset: &mut usize,
    length: u32,
) -> Result<String, PlaylistEngineError> {
    let length: usize = length
        .try_into()
        .map_err(|_| invalid_cache("playlist cache field is too large"))?;
    let end = offset
        .checked_add(length)
        .ok_or_else(|| invalid_cache("playlist cache field overflows"))?;
    let value = bytes
        .get(*offset..end)
        .ok_or_else(|| invalid_cache("playlist cache field is truncated"))?;
    *offset = end;
    std::str::from_utf8(value)
        .map(str::to_string)
        .map_err(|_| invalid_cache("playlist cache field is not UTF-8"))
}

fn read_u32(bytes: &[u8], offset: usize) -> Result<u32, PlaylistEngineError> {
    let value: [u8; 4] = bytes
        .get(offset..offset + 4)
        .ok_or_else(|| invalid_cache("playlist cache is truncated"))?
        .try_into()
        .map_err(|_| invalid_cache("playlist cache integer is invalid"))?;
    Ok(u32::from_le_bytes(value))
}

fn read_u64(bytes: &[u8], offset: usize) -> Result<u64, PlaylistEngineError> {
    let value: [u8; 8] = bytes
        .get(offset..offset + 8)
        .ok_or_else(|| invalid_cache("playlist cache is truncated"))?
        .try_into()
        .map_err(|_| invalid_cache("playlist cache integer is invalid"))?;
    Ok(u64::from_le_bytes(value))
}

fn read_u128(bytes: &[u8], offset: usize) -> Result<u128, PlaylistEngineError> {
    let value: [u8; 16] = bytes
        .get(offset..offset + 16)
        .ok_or_else(|| invalid_cache("playlist cache is truncated"))?
        .try_into()
        .map_err(|_| invalid_cache("playlist cache integer is invalid"))?;
    Ok(u128::from_le_bytes(value))
}

fn source_fingerprint(path: &Path) -> Result<SourceFingerprint, PlaylistEngineError> {
    let metadata = path.metadata().map_err(io_error)?;
    if !metadata.is_file() {
        return Err(invalid_argument("source_path must reference a file"));
    }
    let modified_nanos = metadata
        .modified()
        .unwrap_or(SystemTime::UNIX_EPOCH)
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos()
        .try_into()
        .unwrap_or(u64::MAX);
    Ok(SourceFingerprint {
        size: metadata.len(),
        modified_nanos,
    })
}

fn validate_file_path(value: &str, field: &str) -> Result<PathBuf, PlaylistEngineError> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(invalid_argument(&format!("{field} must not be empty")));
    }
    let path = PathBuf::from(trimmed);
    if !path.is_absolute() {
        return Err(invalid_argument(&format!("{field} must be absolute")));
    }
    Ok(path)
}

fn validate_directory_path(value: &str) -> Result<PathBuf, PlaylistEngineError> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(invalid_argument("cache_directory must not be empty"));
    }
    let path = PathBuf::from(trimmed);
    if !path.is_absolute() {
        return Err(invalid_argument("cache_directory must be absolute"));
    }
    Ok(path)
}

fn normalize_limit(limit: u32) -> Result<u32, PlaylistEngineError> {
    let limit = if limit == 0 {
        DEFAULT_PAGE_LIMIT
    } else {
        limit
    };
    if limit > MAX_PAGE_LIMIT {
        return Err(invalid_argument("page limit must be between 1 and 500"));
    }
    Ok(limit)
}

fn normalize_search(value: &str) -> String {
    value
        .chars()
        .flat_map(char::to_lowercase)
        .filter(|character| character.is_alphanumeric() || character.is_whitespace())
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn normalize_identity(value: &str) -> String {
    value
        .chars()
        .flat_map(char::to_lowercase)
        .filter(|character| character.is_alphanumeric())
        .collect()
}

fn normalize_optional(value: Option<&str>) -> Option<String> {
    value
        .map(normalize_search)
        .filter(|value| !value.is_empty())
}

fn normalize_list(values: &[String]) -> String {
    encode_list(
        &values
            .iter()
            .map(|value| normalize_search(value))
            .filter(|value| !value.is_empty())
            .collect::<Vec<_>>(),
    )
}

fn channel_search_text(channel: &M3uChannel) -> String {
    let scalar_fields = [
        Some(channel.name.as_str()),
        channel.tvg_name.as_deref(),
        channel.group.as_deref(),
        channel.language.as_deref(),
        channel.country.as_deref(),
        channel.provider.as_deref(),
    ];
    scalar_fields
        .into_iter()
        .flatten()
        .chain(channel.aliases.iter().map(String::as_str))
        .chain(channel.tags.iter().map(String::as_str))
        .map(normalize_search)
        .collect::<Vec<_>>()
        .join(" ")
}

const LIST_SEPARATOR: char = '\u{1f}';

fn encode_list(values: &[String]) -> String {
    values
        .iter()
        .map(|value| value.replace(LIST_SEPARATOR, " "))
        .collect::<Vec<_>>()
        .join(&LIST_SEPARATOR.to_string())
}

fn decode_list(value: String) -> Vec<String> {
    if value.is_empty() {
        Vec::new()
    } else {
        value.split(LIST_SEPARATOR).map(str::to_string).collect()
    }
}

fn descriptor_for(
    index_path: &Path,
    cache_path: &Path,
    fingerprint: SourceFingerprint,
    total_channels: u32,
) -> PlaylistIndexDescriptor {
    PlaylistIndexDescriptor {
        index_path: index_path.to_string_lossy().to_string(),
        cache_path: cache_path.to_string_lossy().to_string(),
        total_channels,
        source_size_bytes: fingerprint.size,
        source_modified_nanos: fingerprint.modified_nanos,
    }
}

fn cleanup_temporary_artifacts(cache_dir: &Path) {
    remove_if_exists(&cache_dir.join(CACHE_TEMP_FILE_NAME));
    remove_if_exists(&cache_dir.join(INDEX_TEMP_FILE_NAME));
}

fn sibling(path: &Path, file_name: &str) -> PathBuf {
    path.parent()
        .unwrap_or_else(|| Path::new("."))
        .join(file_name)
}

fn replace_atomically(from: &Path, to: &Path) -> Result<(), PlaylistEngineError> {
    match fs::rename(from, to) {
        Ok(()) => Ok(()),
        Err(first_error) if to.exists() => {
            // Unix atomically replaces the destination in the first call.
            // Some platforms reject an existing destination; fall back to a
            // remove+rename only for that platform behavior.
            fs::remove_file(to).map_err(io_error)?;
            fs::rename(from, to).map_err(|second_error| PlaylistEngineError {
                code: PlaylistEngineErrorCode::Io,
                message: format!(
                    "playlist storage replacement failed: {first_error}; {second_error}"
                ),
            })
        }
        Err(error) => Err(io_error(error)),
    }
}

fn remove_if_exists(path: &Path) {
    if path.exists() {
        let _ = fs::remove_file(path);
    }
}

fn elapsed_micros(started: Instant) -> u64 {
    started.elapsed().as_micros().try_into().unwrap_or(u64::MAX)
}

fn to_sql_i64(value: u64) -> Result<i64, PlaylistEngineError> {
    value
        .try_into()
        .map_err(|_| invalid_argument("source metadata exceeds SQLite integer range"))
}

fn invalid_argument(message: &str) -> PlaylistEngineError {
    PlaylistEngineError {
        code: PlaylistEngineErrorCode::InvalidArgument,
        message: message.to_string(),
    }
}

fn invalid_cache(message: &str) -> PlaylistEngineError {
    PlaylistEngineError {
        code: PlaylistEngineErrorCode::InvalidCache,
        message: message.to_string(),
    }
}

fn io_error(error: std::io::Error) -> PlaylistEngineError {
    PlaylistEngineError {
        code: PlaylistEngineErrorCode::Io,
        message: format!("playlist storage I/O failed: {error}"),
    }
}

fn database_error(error: rusqlite::Error) -> PlaylistEngineError {
    PlaylistEngineError {
        code: PlaylistEngineErrorCode::Database,
        message: format!("playlist index operation failed: {error}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture(channel_count: usize) -> String {
        let mut output = String::from("#EXTM3U\n");
        for index in 0..channel_count {
            output.push_str(&format!(
                "#EXTINF:-1 tvg-id=\"channel.{index}\" tvg-logo=\"https://cdn.example/{index}.png\" group-title=\"News\" tvg-language=\"en\",Channel {index}\nhttps://stream.example/{index}.m3u8\n"
            ));
        }
        output
    }

    fn paths() -> (tempfile::TempDir, PathBuf, PathBuf) {
        let directory = tempfile::tempdir().expect("temporary directory");
        let source = directory.path().join("playlist.m3u");
        let cache = directory.path().join("cache");
        (directory, source, cache)
    }

    #[test]
    fn cold_build_returns_first_page_and_stable_pages() {
        let (_directory, source, cache) = paths();
        fs::write(&source, fixture(125)).expect("write fixture");

        let opened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            25,
        )
        .expect("open index");

        assert_eq!(opened.cache_status, PlaylistCacheStatus::ColdBuilt);
        assert_eq!(opened.descriptor.total_channels, 125);
        assert_eq!(opened.first_page.channels.len(), 25);
        assert_eq!(opened.first_page.channels[0].name, "Channel 0");
        assert!(opened.first_page.has_more);
        assert_eq!(opened.parse_stats.parsed_count, 125);
        assert!(Path::new(&opened.descriptor.cache_path).is_file());
        assert!(Path::new(&opened.descriptor.index_path).is_file());

        let page = page_playlist_index(opened.descriptor.index_path, 100, 50).expect("last page");
        assert_eq!(page.channels.len(), 25);
        assert_eq!(page.channels[0].name, "Channel 100");
        assert!(!page.has_more);
    }

    #[test]
    fn warm_open_does_not_reparse_source() {
        let (_directory, source, cache) = paths();
        fs::write(&source, fixture(20)).expect("write fixture");
        let first = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("cold open");
        let second = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("warm open");

        assert_eq!(first.cache_status, PlaylistCacheStatus::ColdBuilt);
        assert_eq!(second.cache_status, PlaylistCacheStatus::WarmOpened);
        assert_eq!(second.parse_stats.parsed_count, 0);
        assert_eq!(second.first_page.channels, first.first_page.channels);
    }

    #[test]
    fn rebuilds_missing_index_from_mapped_binary_cache() {
        let (_directory, source, cache) = paths();
        fs::write(&source, fixture(20)).expect("write fixture");
        let first = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("cold open");
        fs::remove_file(&first.descriptor.index_path).expect("remove index");

        let reopened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("cache rebuild");

        assert_eq!(
            reopened.cache_status,
            PlaylistCacheStatus::IndexRebuiltFromCache
        );
        assert_eq!(reopened.descriptor.total_channels, 20);
    }

    #[test]
    fn source_change_invalidates_cache_and_index() {
        let (_directory, source, cache) = paths();
        fs::write(&source, fixture(3)).expect("write fixture");
        open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("cold open");
        fs::write(&source, fixture(4)).expect("replace fixture");

        let reopened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("rebuild changed source");

        assert_eq!(reopened.cache_status, PlaylistCacheStatus::ColdBuilt);
        assert_eq!(reopened.descriptor.total_channels, 4);
    }

    #[test]
    fn corrupt_cache_is_rebuilt_from_source() {
        let (_directory, source, cache) = paths();
        fs::write(&source, fixture(3)).expect("write fixture");
        let opened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("cold open");
        fs::write(&opened.descriptor.cache_path, b"corrupt").expect("corrupt cache");

        let reopened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("rebuild corrupt cache");

        assert_eq!(reopened.cache_status, PlaylistCacheStatus::ColdBuilt);
        assert_eq!(reopened.descriptor.total_channels, 3);
    }

    #[test]
    fn search_is_local_bounded_and_ordered() {
        let (_directory, source, cache) = paths();
        fs::write(
            &source,
            "#EXTM3U\n#EXTINF:-1 group-title=\"News\",Hindi News\nhttps://example.com/1\n#EXTINF:-1 group-title=\"Sports\",Hindi Sports\nhttps://example.com/2\n#EXTINF:-1 group-title=\"News\",English News\nhttps://example.com/3\n",
        )
        .expect("write fixture");
        let opened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("open index");

        let results =
            search_playlist_index(opened.descriptor.index_path, "news".to_string(), 0, 10)
                .expect("search");
        assert_eq!(results.total, 2);
        assert_eq!(
            results
                .channels
                .iter()
                .map(|channel| channel.name.as_str())
                .collect::<Vec<_>>(),
            vec!["Hindi News", "English News"]
        );
    }

    #[test]
    fn v2_search_ranks_fields_and_supports_filter_only_intents() {
        let (_directory, source, cache) = paths();
        fs::write(
            &source,
            concat!(
                "#EXTM3U\n",
                "#EXTINF:-1 tvg-name=\"Bharat Sports\" tvg-country=\"IN\" ",
                "provider=\"Public\" tvg-tags=\"cricket,live\" ",
                "group-title=\"Sports\" tvg-language=\"hi\",India Sports\n",
                "https://example.com/india\n",
                "#EXTINF:-1 tvg-country=\"GB\" provider=\"Public\" ",
                "group-title=\"News\" tvg-language=\"en\",Sports News\n",
                "https://example.com/news\n",
                "#EXTINF:-1 tvg-country=\"IN\" provider=\"Private\" ",
                "group-title=\"Kids\" tvg-language=\"hi\",India Kids\n",
                "https://example.com/kids\n",
            ),
        )
        .expect("write fixture");
        let opened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("open index");

        let exact = search_playlist_index_v2(
            opened.descriptor.index_path.clone(),
            Some("India Sports".into()),
            vec![],
            0,
            10,
        )
        .expect("exact search");
        assert_eq!(exact.channels[0].name, "India Sports");
        assert_eq!(exact.channels[0].aliases, ["Bharat Sports"]);
        assert_eq!(exact.channels[0].country.as_deref(), Some("IN"));
        assert_eq!(exact.channels[0].provider.as_deref(), Some("Public"));
        assert_eq!(exact.channels[0].tags, ["cricket", "live"]);

        let filtered = search_playlist_index_v2(
            opened.descriptor.index_path.clone(),
            None,
            vec![
                PlaylistSearchFilter {
                    field: PlaylistSearchField::Country,
                    operator: PlaylistSearchOperator::Equals,
                    value: "in".into(),
                },
                PlaylistSearchFilter {
                    field: PlaylistSearchField::Genre,
                    operator: PlaylistSearchOperator::Equals,
                    value: "sports".into(),
                },
                PlaylistSearchFilter {
                    field: PlaylistSearchField::Tag,
                    operator: PlaylistSearchOperator::Equals,
                    value: "live".into(),
                },
            ],
            0,
            10,
        )
        .expect("filter-only search");
        assert_eq!(filtered.total, 1);
        assert_eq!(filtered.channels[0].name, "India Sports");

        let alias = search_playlist_index_v2(
            opened.descriptor.index_path,
            Some("bharat".into()),
            vec![],
            0,
            10,
        )
        .expect("alias prefix search");
        assert_eq!(alias.channels[0].name, "India Sports");
    }

    #[test]
    fn v2_search_uses_bounded_fuzzy_fallback_and_rejects_empty_requests() {
        let (_directory, source, cache) = paths();
        fs::write(
            &source,
            "#EXTM3U\n#EXTINF:-1 group-title=\"Sports\",India Sports\nhttps://example.com/1\n",
        )
        .expect("write fixture");
        let opened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("open index");

        let fuzzy = search_playlist_index_v2(
            opened.descriptor.index_path.clone(),
            Some("India Sprts".into()),
            vec![],
            0,
            10,
        )
        .expect("fuzzy search");
        assert_eq!(fuzzy.channels[0].name, "India Sports");

        let error = search_playlist_index_v2(
            opened.descriptor.index_path,
            Some(" ".into()),
            vec![],
            0,
            10,
        )
        .expect_err("empty search rejected");
        assert_eq!(error.code, PlaylistEngineErrorCode::InvalidArgument);
    }

    #[test]
    fn deduplicates_using_existing_parser_semantics() {
        let (_directory, source, cache) = paths();
        fs::write(
            &source,
            "#EXTM3U\n#EXTINF:-1,News One\nhttps://example.com/no-logo\n#EXTINF:-1 tvg-logo=\"https://example.com/logo.png\",news-one\nhttps://example.com/with-logo\n",
        )
        .expect("write fixture");
        let opened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("open index");

        assert_eq!(opened.descriptor.total_channels, 1);
        assert_eq!(
            opened.first_page.channels[0].url,
            "https://example.com/with-logo"
        );
    }

    #[test]
    fn rejects_relative_paths_empty_queries_and_oversized_pages() {
        let error = open_playlist_index("relative.m3u".into(), "/tmp".into(), 10)
            .expect_err("relative source rejected");
        assert_eq!(error.code, PlaylistEngineErrorCode::InvalidArgument);

        let (_directory, source, cache) = paths();
        fs::write(&source, fixture(1)).expect("write fixture");
        let opened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            0,
        )
        .expect("default page");
        assert_eq!(opened.first_page.channels.len(), 1);

        assert_eq!(
            page_playlist_index(opened.descriptor.index_path.clone(), 0, 501)
                .expect_err("oversized page")
                .code,
            PlaylistEngineErrorCode::InvalidArgument
        );
        assert_eq!(
            search_playlist_index(opened.descriptor.index_path, " ".into(), 0, 10)
                .expect_err("empty query")
                .code,
            PlaylistEngineErrorCode::InvalidArgument
        );
    }

    #[test]
    fn invalid_utf8_is_counted_without_panicking() {
        let (_directory, source, cache) = paths();
        fs::write(
            &source,
            b"#EXTM3U\n#EXTINF:-1,Invalid\n\xff\xfe\n#EXTINF:-1,Valid\nhttps://example.com/ok\n",
        )
        .expect("write fixture");

        let opened = open_playlist_index(
            source.to_string_lossy().to_string(),
            cache.to_string_lossy().to_string(),
            10,
        )
        .expect("open index");

        assert_eq!(opened.parse_stats.malformed_count, 1);
        assert_eq!(opened.descriptor.total_channels, 1);
    }
}
