# Coins DB Schema Changelog and Migration Runbook

Status: documented for the current Coins persistence model in `app/lib/core/database/app_database_native.dart` and the web Hive box shim in `app/lib/core/database/app_database_web.dart`.

## Scope

Coins data is stored in the shared app database file `airo_money.db` on native platforms through Drift/SQLite. On web, the same logical datasets are stored as Hive boxes using the native table names as box names.

This document covers the Coins-facing database additions and the migration steps required when moving an installed app from the earlier money-only schema to the schema that includes Coins categories, groups, shared expenses, split entries, settlements, outbox entries, and sync metadata.

## Current implementation snapshot

Source of truth:

- Native schema: `app/lib/core/database/app_database_native.dart`
- Generated Drift bindings: `app/lib/core/database/app_database_native.g.dart`
- Web storage shim: `app/lib/core/database/app_database_web.dart`

Current code state:

- `AppDatabase.schemaVersion` is `1` in both native and web implementations.
- Native `onCreate` calls `m.createAll()`, so fresh installs receive every table below.
- Native `onUpgrade` is currently a no-op.
- `beforeOpen` enables `foreign_keys`, WAL journal mode, `synchronous = NORMAL`, and a larger cache.
- Web uses Hive boxes named after the native tables and reports a simulated schema version of `1`.

Important migration note: if a release has already shipped with a smaller schema at version `1`, adding these tables under the same schema version is not enough for existing native users. The app must bump the native schema version and create the missing Coins tables in `onUpgrade`.

## Changelog

### v1: Money + Coins baseline for fresh installs

Fresh installs create the following logical datasets:

Existing money datasets:

- `transaction_entries`: personal expense/income transactions.
- `budget_entries`: category/tag budget limits and usage.
- `account_entries`: financial accounts.

Coins additions:

- `category_entries`: categories and subcategories for transaction classification.
- `group_entries`: split-expense groups.
- `group_member_entries`: group participants and default shares.
- `shared_expense_entries`: group expenses paid by a member.
- `split_entry_records`: individual participant shares for shared expenses.
- `settlement_entries`: payments between members to settle balances.
- `outbox_entries`: offline-first create/update/delete operations queued for sync.
- `sync_metadata`: key/value sync checkpoints and cursors.

Behavioral changes:

- Coins amount fields use the smallest currency unit, for example paise or cents.
- Split groups and shared expenses default to `INR` when no currency is supplied.
- Sync-enabled rows default to `sync_status = 'pending'`.
- Soft delete is available for shared expenses through `is_deleted`.
- Sync metadata uses `key` as its primary key.

### Proposed v2 migration: money-only v1 to Coins-enabled schema

Use this migration when an installed app may have only the earlier money tables but now needs the Coins tables.

Schema version change:

- Native: increase `AppDatabase.schemaVersion` from `1` to `2`.
- Web: keep the Hive API stable, but add an app-level migration marker in `sync_metadata` such as `coins_schema_version = 2` after opening/creating the new boxes.

Native Drift migration steps:

1. In `onUpgrade`, handle `from < 2`.
2. Create the new tables with `await m.createTable(...)` for:
   - `categoryEntries`
   - `groupEntries`
   - `groupMemberEntries`
   - `sharedExpenseEntries`
   - `splitEntryRecords`
   - `settlementEntries`
   - `outboxEntries`
   - `syncMetadata`
3. Do not drop or rewrite `transaction_entries`, `budget_entries`, or `account_entries`.
4. Keep defaults on all new non-null columns so existing users do not need data backfills for these new tables.
5. After creating tables, write a migration marker to `sync_metadata`, for example `coins_schema_version = 2` and `coins_schema_migrated_at = <UTC ISO timestamp>`.
6. Run a smoke test that opens a pre-v2 database, upgrades it, and verifies that every Coins table exists.

Suggested native code shape:

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll();
  },
  onUpgrade: (Migrator m, int from, int to) async {
    if (from < 2) {
      await m.createTable(categoryEntries);
      await m.createTable(groupEntries);
      await m.createTable(groupMemberEntries);
      await m.createTable(sharedExpenseEntries);
      await m.createTable(splitEntryRecords);
      await m.createTable(settlementEntries);
      await m.createTable(outboxEntries);
      await m.createTable(syncMetadata);
    }
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
    await customStatement('PRAGMA journal_mode = WAL');
    await customStatement('PRAGMA synchronous = NORMAL');
    await customStatement('PRAGMA cache_size = 10000');
  },
);
```

If any of these tables may already exist because of prerelease builds that created them without a schema bump, use guarded SQL instead of unguarded `m.createTable(...)` for those environments, or run a one-off prerelease migration test before shipping.

## Native table reference

### category_entries

Purpose: category taxonomy for Coins transactions.

Columns:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `uuid TEXT UNIQUE NOT NULL`
- `name TEXT NOT NULL`
- `icon_name TEXT NOT NULL DEFAULT 'category'`
- `color_hex TEXT NOT NULL DEFAULT '#808080'`
- `category_type TEXT NOT NULL DEFAULT 'expense'`
- `parent_id TEXT NULL`
- `sort_order INTEGER NOT NULL DEFAULT 0`
- `is_active INTEGER/BOOLEAN NOT NULL DEFAULT true`
- `sync_status TEXT NOT NULL DEFAULT 'pending'`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NULL`

### group_entries

Purpose: split-expense group metadata.

Columns:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `uuid TEXT UNIQUE NOT NULL`
- `name TEXT NOT NULL`
- `description TEXT NULL`
- `icon_url TEXT NULL`
- `created_by_user_id TEXT NOT NULL`
- `default_currency TEXT NOT NULL DEFAULT 'INR'`
- `simplify_debts INTEGER/BOOLEAN NOT NULL DEFAULT true`
- `is_active INTEGER/BOOLEAN NOT NULL DEFAULT true`
- `invite_code TEXT NULL`
- `sync_status TEXT NOT NULL DEFAULT 'pending'`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NULL`

### group_member_entries

Purpose: members of each split-expense group.

Columns:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `uuid TEXT UNIQUE NOT NULL`
- `group_id TEXT NOT NULL`
- `user_id TEXT NOT NULL`
- `display_name TEXT NOT NULL`
- `email TEXT NULL`
- `avatar_url TEXT NULL`
- `role TEXT NOT NULL DEFAULT 'member'`
- `default_share_percent INTEGER NOT NULL DEFAULT 100`
- `is_active INTEGER/BOOLEAN NOT NULL DEFAULT true`
- `sync_status TEXT NOT NULL DEFAULT 'pending'`
- `joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NULL`

### shared_expense_entries

Purpose: expenses recorded against a group.

Columns:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `uuid TEXT UNIQUE NOT NULL`
- `group_id TEXT NOT NULL`
- `description TEXT NOT NULL`
- `total_amount_cents INTEGER NOT NULL`
- `currency_code TEXT NOT NULL DEFAULT 'INR'`
- `paid_by_user_id TEXT NOT NULL`
- `category_id TEXT NULL`
- `split_type TEXT NOT NULL DEFAULT 'equal'`
- `notes TEXT NULL`
- `receipt_url TEXT NULL`
- `is_deleted INTEGER/BOOLEAN NOT NULL DEFAULT false`
- `sync_status TEXT NOT NULL DEFAULT 'pending'`
- `expense_date DATETIME NOT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NULL`

### split_entry_records

Purpose: individual shares for a shared expense.

Columns:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `uuid TEXT UNIQUE NOT NULL`
- `shared_expense_id TEXT NOT NULL`
- `user_id TEXT NOT NULL`
- `amount_cents INTEGER NOT NULL`
- `share_value INTEGER NOT NULL DEFAULT 100`
- `is_settled INTEGER/BOOLEAN NOT NULL DEFAULT false`
- `sync_status TEXT NOT NULL DEFAULT 'pending'`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NULL`

### settlement_entries

Purpose: settlement payments between group members.

Columns:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `uuid TEXT UNIQUE NOT NULL`
- `group_id TEXT NOT NULL`
- `from_user_id TEXT NOT NULL`
- `to_user_id TEXT NOT NULL`
- `amount_cents INTEGER NOT NULL`
- `currency_code TEXT NOT NULL DEFAULT 'INR'`
- `payment_method TEXT NULL`
- `payment_reference TEXT NULL`
- `notes TEXT NULL`
- `status TEXT NOT NULL DEFAULT 'pending'`
- `settled_at DATETIME NULL`
- `sync_status TEXT NOT NULL DEFAULT 'pending'`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `updated_at DATETIME NULL`

### outbox_entries

Purpose: durable offline sync operation queue.

Columns:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `operation_id TEXT UNIQUE NOT NULL`
- `entity_type TEXT NOT NULL`
- `entity_id TEXT NOT NULL`
- `operation_type TEXT NOT NULL`
- `payload TEXT NOT NULL`
- `priority INTEGER NOT NULL DEFAULT 1`
- `status TEXT NOT NULL DEFAULT 'pending'`
- `retry_count INTEGER NOT NULL DEFAULT 0`
- `last_error TEXT NULL`
- `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- `last_attempt_at DATETIME NULL`

### sync_metadata

Purpose: sync cursors, schema markers, and idempotency checkpoints.

Columns:

- `key TEXT PRIMARY KEY NOT NULL`
- `value TEXT NOT NULL`
- `updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`

## Web migration steps

Hive creates boxes lazily, so the web migration is mostly a compatibility marker and data-shape validation.

1. Open or create these boxes:
   - `category_entries`
   - `group_entries`
   - `group_member_entries`
   - `shared_expense_entries`
   - `split_entry_records`
   - `settlement_entries`
   - `outbox_entries`
   - `sync_metadata`
2. Do not rename existing boxes.
3. For prerelease data, normalize missing optional fields in read mappers rather than rewriting all records eagerly.
4. Write `coins_schema_version = 2` to `sync_metadata` after the boxes have been opened successfully.
5. If initialization fails, leave existing boxes untouched and retry on the next launch.

## Data safety and compatibility

- The Coins migration is additive when moving from the money-only schema.
- Existing transaction, budget, and account rows are preserved.
- New table defaults avoid mandatory backfills for existing users.
- No destructive migration is required for the documented v2 path.
- Because the Drift tables currently do not declare foreign-key constraints, referential integrity between groups, members, shared expenses, split entries, and settlements must be enforced in repositories/services until database constraints are added in a future schema version.

## Rollback procedure

Code rollback before migration ships:

- Revert the code changes and this runbook update.
- No user data exists in the new Coins tables if the migration was never released.

Runtime rollback after v2 ships:

1. Prefer a forward-fix release over dropping tables.
2. Keep the schema version at `2` or higher; do not downgrade the on-device schema version.
3. Disable Coins UI/routes with a feature flag if needed.
4. Leave Coins tables in place to preserve user data.
5. If a hotfix must stop sync, pause processing of `outbox_entries` but do not delete queued operations.

Destructive rollback for development-only databases:

```sql
DROP TABLE IF EXISTS settlement_entries;
DROP TABLE IF EXISTS split_entry_records;
DROP TABLE IF EXISTS shared_expense_entries;
DROP TABLE IF EXISTS group_member_entries;
DROP TABLE IF EXISTS group_entries;
DROP TABLE IF EXISTS category_entries;
DROP TABLE IF EXISTS outbox_entries;
DROP TABLE IF EXISTS sync_metadata;
```

Do not run the destructive rollback on production user databases unless data loss has been explicitly approved.

## Validation checklist

Before shipping a native migration:

- Fresh install creates all money and Coins tables.
- Upgrade from a money-only database creates all Coins tables.
- Upgrade is idempotent for prerelease databases if guarded SQL is used.
- Existing transaction, budget, and account counts are unchanged after upgrade.
- `foreign_keys`, WAL, `synchronous = NORMAL`, and cache PRAGMAs still apply after migration.
- Coins repository tests pass for expense creation, split workflow, currency hygiene, and dashboard reads.
- Web opens all expected Hive boxes and preserves existing box data.
