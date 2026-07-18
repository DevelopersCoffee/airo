/// Typed ContentSource contract (M3U, Xtream Codes, Stalker Portal,
/// Jellyfin) and provider adapters for Airo TV.
library platform_playlist;

export 'package:platform_channels/platform_channels.dart'
    show VodItem, VodContentKind;

export 'src/content_source.dart';
export 'src/content_source_credential_store.dart';
export 'src/provider_health.dart';
export 'src/provider_health_recorder.dart';
export 'src/m3u_content_source.dart';
export 'src/m3u_vod_adapter.dart';
export 'src/xtream/xtream_client.dart';
export 'src/xtream/xtream_content_source.dart';
export 'src/xtream/xtream_epg_repository.dart';
export 'src/xtream/xtream_vod_adapter.dart';
export 'src/stalker/stalker_client.dart';
export 'src/stalker/stalker_content_source.dart';
export 'src/stalker/stalker_epg_repository.dart';
export 'src/jellyfin/jellyfin_client.dart';
export 'src/jellyfin/jellyfin_content_source.dart';
export 'src/jellyfin/jellyfin_epg_repository.dart';
