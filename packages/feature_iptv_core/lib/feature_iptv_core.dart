/// Platform-agnostic IPTV domain logic, shared by every shell that renders
/// IPTV UI (mobile, TV, and any future shell). No Flutter widget classes or
/// per-shell presentation live here — see ADR-0011 and
/// `tasks/ssot_airo_airo_tv_architecture_blueprint.md`.
library;

export 'src/favorite_reimport_coordinator.dart';
export 'src/iptv_navigation_manifest.dart';
export 'src/iptv_settings_manifest.dart';
export 'src/local_iptv_search.dart';
export 'src/vod_resume_coordinator.dart';
export 'src/vod_series_grouping.dart';
export 'src/wakelock_debouncer.dart';
