# Database Reliability Validation

Deterministic validation runbook for issue `#516`.

This slice covers native database migration/open behavior, malformed-file
recovery, backup/restore, and larger local-history durability.

## Automated Checks

Run the shared database-reliability suite from the repository root:

```sh
make test-database-reliability
```

Current automated coverage proves:

- native database opens with expected SQLite PRAGMAs
- malformed database files are recreated into a usable schema on open
- exported backup bytes restore into a fresh database instance
- larger local histories survive backup/restore round trips without row loss

## Host-Runnable Acceptance

The automated portion passes when:

- the command succeeds with no failing tests
- restored databases preserve the expected row count and sample records
- malformed database files do not crash the open path
- the recreated schema remains queryable after recovery

## Manual / Device Matrix

These checks still require device or manual verification because they depend on
real user state, upgrade paths, or file transfer behavior outside host tests.

| Scenario | Steps | Expected |
| --- | --- | --- |
| Migration | Install older app build or fixture DB, then upgrade | Existing data opens without destructive migration |
| Crash recovery | Kill app during active DB writes, relaunch | Database remains readable and app recovers safely |
| Corrupted database | Replace DB with malformed file on a test device, relaunch | App recreates a usable DB instead of crashing |
| Large meeting history | Import or generate large local history, relaunch and query | Reads remain responsive and complete |
| Search indexing | Verify persisted feature data remains queryable after restore/upgrade | Relevant search surfaces still return expected items |
| Backup | Export native DB file | Backup artifact is produced and readable |
| Restore | Restore backup onto device or local fixture path | App opens restored data correctly |

## Suggested Android Checks

Use a connected device when possible:

```sh
make run-android-auto
```

Then manually verify:

1. Start with real local data, force-stop the app during active usage, and relaunch.
2. Replace the on-device database with a backed-up copy and confirm the app opens.
3. Exercise a large local dataset and confirm reads/search still work after relaunch.
4. Record any upgrade, corruption, or restore deviations in the PR or release notes.

## Evidence to Attach Before Closing

Before issue `#516` can be closed, attach:

- output from `make test-database-reliability`
- notes for any exercised migration/crash-recovery/device restore paths
- any waived manual checks or known platform limitations
