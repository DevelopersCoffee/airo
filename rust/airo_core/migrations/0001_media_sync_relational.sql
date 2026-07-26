PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  applied_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
  uuid TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE IF NOT EXISTS devices (
  uuid TEXT PRIMARY KEY,
  user_uuid TEXT NOT NULL REFERENCES users(uuid) ON DELETE CASCADE,
  device_class TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE IF NOT EXISTS profiles (
  uuid TEXT PRIMARY KEY,
  user_uuid TEXT NOT NULL REFERENCES users(uuid) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE IF NOT EXISTS playlists (
  uuid TEXT PRIMARY KEY,
  profile_uuid TEXT NOT NULL REFERENCES profiles(uuid) ON DELETE CASCADE,
  name TEXT NOT NULL,
  source_ref TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  UNIQUE(profile_uuid, source_ref)
);

CREATE TABLE IF NOT EXISTS channels (
  uuid TEXT PRIMARY KEY,
  playlist_uuid TEXT NOT NULL REFERENCES playlists(uuid) ON DELETE CASCADE,
  canonical_name TEXT NOT NULL,
  channel_number TEXT,
  language_code TEXT,
  country_code TEXT,
  provider_name TEXT,
  raw_provider_metadata TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE IF NOT EXISTS history (
  uuid TEXT PRIMARY KEY,
  profile_uuid TEXT NOT NULL REFERENCES profiles(uuid) ON DELETE CASCADE,
  media_uuid TEXT NOT NULL,
  channel_uuid TEXT REFERENCES channels(uuid) ON DELETE SET NULL,
  position_ms INTEGER NOT NULL CHECK(position_ms >= 0),
  duration_ms INTEGER NOT NULL CHECK(duration_ms > 0),
  status TEXT NOT NULL,
  watched_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE IF NOT EXISTS favorites (
  uuid TEXT PRIMARY KEY,
  profile_uuid TEXT NOT NULL REFERENCES profiles(uuid) ON DELETE CASCADE,
  channel_uuid TEXT NOT NULL REFERENCES channels(uuid) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  UNIQUE(profile_uuid, channel_uuid)
);

CREATE TABLE IF NOT EXISTS collections (
  uuid TEXT PRIMARY KEY,
  profile_uuid TEXT NOT NULL REFERENCES profiles(uuid) ON DELETE CASCADE,
  name TEXT NOT NULL,
  collection_kind TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE IF NOT EXISTS collection_items (
  collection_uuid TEXT NOT NULL REFERENCES collections(uuid) ON DELETE CASCADE,
  media_uuid TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(collection_uuid, media_uuid)
);

CREATE TABLE IF NOT EXISTS settings (
  profile_uuid TEXT NOT NULL REFERENCES profiles(uuid) ON DELETE CASCADE,
  setting_key TEXT NOT NULL,
  value_type TEXT NOT NULL,
  text_value TEXT,
  integer_value INTEGER,
  real_value REAL,
  boolean_value INTEGER CHECK(boolean_value IN (0, 1)),
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  PRIMARY KEY(profile_uuid, setting_key)
);

CREATE TABLE IF NOT EXISTS sync_events (
  uuid TEXT PRIMARY KEY,
  entity_uuid TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  transport_kind TEXT NOT NULL,
  operation_kind TEXT NOT NULL,
  status TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  applied_at INTEGER
);

CREATE TABLE IF NOT EXISTS knowledge_packs (
  pack_id TEXT PRIMARY KEY,
  schema_version TEXT NOT NULL,
  loaded_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS media_titles (
  uuid TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  release_year INTEGER NOT NULL,
  content_rating TEXT
);

CREATE TABLE IF NOT EXISTS media_entities (
  uuid TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  name TEXT NOT NULL,
  UNIQUE(entity_type, name)
);

CREATE TABLE IF NOT EXISTS media_edges (
  title_uuid TEXT NOT NULL REFERENCES media_titles(uuid) ON DELETE CASCADE,
  entity_uuid TEXT NOT NULL REFERENCES media_entities(uuid) ON DELETE CASCADE,
  PRIMARY KEY(title_uuid, entity_uuid)
);

CREATE TABLE IF NOT EXISTS pack_title_owners (
  pack_id TEXT NOT NULL REFERENCES knowledge_packs(pack_id) ON DELETE CASCADE,
  title_uuid TEXT NOT NULL REFERENCES media_titles(uuid) ON DELETE CASCADE,
  PRIMARY KEY(pack_id, title_uuid)
);

CREATE TABLE IF NOT EXISTS pack_entity_owners (
  pack_id TEXT NOT NULL REFERENCES knowledge_packs(pack_id) ON DELETE CASCADE,
  entity_uuid TEXT NOT NULL REFERENCES media_entities(uuid) ON DELETE CASCADE,
  PRIMARY KEY(pack_id, entity_uuid)
);

CREATE TABLE IF NOT EXISTS sync_entities (
  uuid TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  schema_version TEXT NOT NULL,
  entity_version INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

CREATE TABLE IF NOT EXISTS sync_fields (
  entity_uuid TEXT NOT NULL REFERENCES sync_entities(uuid) ON DELETE CASCADE,
  field_name TEXT NOT NULL,
  value_type TEXT NOT NULL,
  text_value TEXT,
  integer_value INTEGER,
  real_value REAL,
  boolean_value INTEGER CHECK(boolean_value IN (0, 1)),
  updated_at INTEGER NOT NULL,
  origin_node_id TEXT NOT NULL,
  PRIMARY KEY(entity_uuid, field_name)
);

CREATE TABLE IF NOT EXISTS sync_vector_counters (
  entity_uuid TEXT NOT NULL REFERENCES sync_entities(uuid) ON DELETE CASCADE,
  field_name TEXT NOT NULL DEFAULT '',
  node_id TEXT NOT NULL,
  counter INTEGER NOT NULL CHECK(counter >= 0),
  PRIMARY KEY(entity_uuid, field_name, node_id)
);

CREATE INDEX IF NOT EXISTS idx_history_profile_watched
  ON history(profile_uuid, watched_at DESC);
CREATE INDEX IF NOT EXISTS idx_favorites_profile_active
  ON favorites(profile_uuid, deleted_at);
CREATE INDEX IF NOT EXISTS idx_channels_playlist_active
  ON channels(playlist_uuid, deleted_at);
CREATE INDEX IF NOT EXISTS idx_media_titles_year
  ON media_titles(release_year);
CREATE INDEX IF NOT EXISTS idx_media_entities_type_name
  ON media_entities(entity_type, name);
CREATE INDEX IF NOT EXISTS idx_sync_events_status_created
  ON sync_events(status, created_at);
CREATE INDEX IF NOT EXISTS idx_sync_entities_tombstones
  ON sync_entities(deleted_at);

INSERT OR IGNORE INTO schema_migrations(version, applied_at)
VALUES (1, unixepoch());
