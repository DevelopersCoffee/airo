# Plugin Kill Switch Runbook

This runbook describes how to remotely disable and re-enable Airo plugins without shipping an app update.

## Config schema

The runtime config is a JSON object hosted on CDN/object storage and fetched by `RemotePluginKillSwitchService`.

```json
{
  "version": "2026-02-09T12:00:00Z",
  "default_enabled": true,
  "plugins": {
    "com.airo.plugin.beats": {
      "enabled": true,
      "min_version": "1.0.0",
      "max_version": null,
      "message": null
    },
    "com.airo.plugin.games": {
      "enabled": false,
      "max_version": "1.2.3",
      "message": "Games temporarily unavailable for maintenance",
      "disabled_at": "2026-02-09T10:00:00Z",
      "eta_restore": "2026-02-09T14:00:00Z"
    }
  }
}
```

Fields:
- `version`: monotonically changing config version, preferably an ISO-8601 UTC timestamp.
- `default_enabled`: whether unknown plugin IDs are enabled. Keep this `true` unless a global plugin outage is required.
- `plugins.<plugin_id>.enabled`: base allow/deny state.
- `min_version` / `max_version`: optional targeted version range. A disabled rule only blocks versions inside this range.
- `message`: user-facing text shown when the plugin is disabled.
- `disabled_at`: audit timestamp for when a disable action started.
- `eta_restore`: optional expected restore time.
- `cohort`: optional rollout, region, or A/B cohort label.

## Runtime integration

1. App startup creates `RemotePluginKillSwitchService(configUrl: ...)` and calls `refresh()`.
2. Plugin loading uses `KillSwitchAwarePluginLoader(delegate: ..., killSwitch: ...)`.
3. Before loading a plugin, the wrapper calls `isPluginEnabled(pluginId)`.
4. Disabled plugins return `PluginLoadResult.failure(pluginId, message)`; UI should display that message instead of a generic error.
5. The app can subscribe to `watchUpdates()` and unload/disable active plugins if a later refresh disables them.
6. Schedule periodic refreshes at least hourly. For urgent rollbacks, send a push notification that triggers `refresh()` immediately.

## CDN hosting requirements

Host the JSON at a stable HTTPS URL such as:

`https://cdn.airo.app/config/plugin-kill-switch.json`

Recommended cache headers:

```text
Cache-Control: public, max-age=300, stale-while-revalidate=3600
Content-Type: application/json
ETag: <object etag>
```

Operational notes:
- Use a short `max-age` so emergency disables propagate quickly.
- Keep object versioning enabled for rollback/audit.
- Protect writes behind admin credentials and review for production config.
- Do not include secrets in this file; it is public client config.

## Admin tool

Use the helper script to edit and validate config before uploading it to CDN/object storage.

Validate:

```bash
scripts/plugin_kill_switch_admin.py validate config/plugin-kill-switch.json
```

Disable a plugin version range:

```bash
scripts/plugin_kill_switch_admin.py disable config/plugin-kill-switch.json \
  com.airo.plugin.games \
  --message "Games temporarily unavailable for maintenance" \
  --max-version 1.2.3 \
  --eta-restore 2026-02-09T14:00:00Z
```

Re-enable a plugin:

```bash
scripts/plugin_kill_switch_admin.py enable config/plugin-kill-switch.json \
  com.airo.plugin.games
```

After editing:

1. Validate the JSON.
2. Upload it to the CDN/object storage location.
3. Purge CDN cache if this is an emergency rollback.
4. Confirm a device fetches the new `version`.
5. Watch crash/error dashboards for recovery.

## Emergency rollback checklist

- [ ] Confirm plugin ID and affected version range.
- [ ] Disable only affected versions when possible.
- [ ] Set a clear user-facing message.
- [ ] Set `disabled_at` and optional `eta_restore`.
- [ ] Validate config with `scripts/plugin_kill_switch_admin.py validate`.
- [ ] Upload to CDN/object storage.
- [ ] Purge CDN cache for the config object.
- [ ] Trigger push-refresh if available.
- [ ] Verify `KillSwitchAwarePluginLoader` blocks the plugin and surfaces the message.
- [ ] Create follow-up incident/bug ticket for permanent remediation.
